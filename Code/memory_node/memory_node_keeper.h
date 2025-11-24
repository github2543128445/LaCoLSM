//
// Created by ruihong on 7/29/21.
//

#ifndef TimberSaw_HOME_NODE_KEEPER_H
#define TimberSaw_HOME_NODE_KEEPER_H


#include <queue>
#include <tuple>
#include <fstream>
#include <iostream>
//#include <fcntl.h>
#include "util/rdma.h"
#include "util/env_posix.h"
#include "util/ThreadPool.h"
#include "db/log_writer.h"
#include "db/version_set.h"

namespace TimberSaw {

struct Arg_for_persistent{
  VersionEdit_Merger* edit_merger;
  std::string client_ip;
  uint8_t target_node_id;
};
class Memory_Node_Keeper {
 public:
//  friend class RDMA_Manager;
  Memory_Node_Keeper(bool use_sub_compaction, uint32_t tcp_port, int pr_s);
  ~Memory_Node_Keeper();
//  void Schedule(
//      void (*background_work_function)(void* background_work_arg),
//      void* background_work_arg, ThreadPoolType type);
  void JoinAllThreads(bool wait_for_jobs_to_complete);

  // this function is for the server.
  void Server_to_Client_Communication();
  void SetBackgroundThreads(int num,  ThreadPoolType type);
//  void MaybeScheduleCompaction(std::string& client_ip);
//  static void BGWork_Compaction(void* thread_args);
  static void RPC_Compaction_Dispatch(void* thread_args);
  static void RPC_Garbage_Collection_Dispatch(void* thread_args);
  static void Persistence_Dispatch(void* thread_args);
//  void BackgroundCompaction(void* p);
  void CleanupCompaction(CompactionState* compact);
  void PersistSSTables(void* arg);
  void PersistSSTable(std::shared_ptr<RemoteMemTableMetaData> sstable_ptr);
  //WHen persist  a bunch of merged edit, unpin those deleted file in the merged edit.
  void UnpinSSTables_RPC(VersionEdit_Merger* edit_merger,
                         std::string& client_ip, uint8_t target_node_id);
  //during the edit merge, unpin those merged files.
  void UnpinSSTables_RPC(std::list<uint64_t>* merged_file_number,
                         std::string& client_ip, uint8_t target_node_id);
  Status DoCompactionWork(CompactionState* compact, std::string& client_ip);
  void ProcessKeyValueCompaction(SubcompactionState* sub_compact);
  void ProcessKeyValueCompactionPlusCases(SubcompactionState* sub_compact,int cases);
  Status DoCompactionWorkWithSubcompaction(CompactionState* compact,
                                           std::string& client_ip);
  Status OpenCompactionOutputFile(SubcompactionState* compact);
  Status OpenCompactionOutputFile(CompactionState* compact);
  Status FinishCompactionOutputFile(SubcompactionState* compact,
                                    Iterator* input);
  Status FinishCompactionOutputFile(CompactionState* compact, Iterator* input);
  Status GetFileSize(const std::string& filename, uint64_t* size) {
    struct ::stat file_stat;
    if (::stat(filename.c_str(), &file_stat) != 0) {
      *size = 0;
      return PosixError(filename, errno);
    }
    *size = file_stat.st_size;
    return Status::OK();
  }
  Status NewSequentialFile(const std::string& filename,
                           SequentialFile** result)  {
    int fd = ::open(filename.c_str(), O_RDONLY | kOpenBaseFlags);
    if (fd < 0) {
      *result = nullptr;
      return PosixError(filename, errno);
    }

    *result = new PosixSequentialFile(filename, fd);
    return Status::OK();
  }

  Status NewRandomAccessFile(const std::string& filename,
                             RandomAccessFile** result)  {
    *result = nullptr;
    int fd = ::open(filename.c_str(), O_RDONLY | kOpenBaseFlags);
    if (fd < 0) {
      return PosixError(filename, errno);
    }

    if (!mmap_limiter_.Acquire()) {
      *result = new PosixRandomAccessFile(filename, fd, &fd_limiter_);
      return Status::OK();
    }

    uint64_t file_size;
    Status status = GetFileSize(filename, &file_size);
    if (status.ok()) {
      void* mmap_base =
          ::mmap(/*addr=*/nullptr, file_size, PROT_READ, MAP_SHARED, fd, 0);
      if (mmap_base != MAP_FAILED) {
        *result = new PosixMmapReadableFile(filename,
                                            reinterpret_cast<char*>(mmap_base),
                                            file_size, &mmap_limiter_);
      } else {
        status = PosixError(filename, errno);
      }
    }
    ::close(fd);
    if (!status.ok()) {
      mmap_limiter_.Release();
    }
    return status;
  }

  Status NewWritableFile(const std::string& filename,
                         WritableFile** result) {
    int fd = ::open(filename.c_str(),
                    O_TRUNC | O_WRONLY | O_CREAT | kOpenBaseFlags, 0644);
    if (fd < 0) {
      *result = nullptr;
      assert(false);
      return PosixError(filename, errno);
    }

    *result = new PosixWritableFile(filename, fd);
//    printf("file object is %p", *result);
    return Status::OK();
  }

  Status NewAppendableFile(const std::string& filename,
                           WritableFile** result)  {
    int fd = ::open(filename.c_str(),
                    O_APPEND | O_WRONLY | O_CREAT | kOpenBaseFlags, 0644);
    if (fd < 0) {
      *result = nullptr;
      return PosixError(filename, errno);
    }

    *result = new PosixWritableFile(filename, fd);
    return Status::OK();
  }

  bool FileExists(const std::string& filename)  {
    return ::access(filename.c_str(), F_OK) == 0;
  }
  std::shared_ptr<Options> get_opt(){return opts;}//LZY add
  void set_usesubcompaction(bool b){usesubcompaction=b;}//LZY add
  static std::shared_ptr<RDMA_Manager> rdma_mg;
//  RDMA_Manager* rdma_mg;


  //LZYADD ↓
  std::deque<std::tuple<int,double,int>> C1_[4][5]; //  [case][stage] -> (filenum,av_core,time)   5个stage:解析任务，读table，排序，写table，整理并发回元数据改动
  std::mutex C1_mutex;
  void C1_append(int filenum,double av_core,int time,int cases,int stage){
    std::lock_guard<std::mutex> lock(C1_mutex);
    C1_[cases][stage].push_back(std::make_tuple(filenum,av_core,time));
  }
  void print_C1_to_file(){
    std::lock_guard<std::mutex> lock(C1_mutex); // 确保遍历期间数据不被修改

    // 遍历所有case（0~3）和stage（0~4）
    for (int cases = 0; cases < 4; ++cases) {
      for (int stage = 0; stage < 5; ++stage) {
        // 构造文件名：C1_[case]_[stage].csv
        std::string filename = "../C1_" + std::to_string(cases+1) + "_" + std::to_string(stage+1) + ".csv";  

        // 打开文件（若存在则覆盖，用trunc模式；若需追加可改为app）
        std::ofstream csv_file(filename, std::ios::app);
        if (!csv_file.is_open()) {
            std::cerr << "Error: 无法打开文件 " << filename << std::endl;
            continue; // 跳过当前文件，处理下一个
        }
        // 遍历当前[case][stage]对应的deque，写入每一行数据
        for (const auto& elem : C1_[cases][stage]) {
            int filenum = std::get<0>(elem);
            double av_core = static_cast<double>(rdma_mg->rpter.numa_bind_core_num) - std::get<1>(elem) / 100.0;
            int time = std::get<2>(elem);

            // 计算speed（处理time=0的情况）
            double speed = (filenum != 0) ? time/static_cast<double>(filenum) : 0.0;

            // 写入一行数据
            csv_file << filenum << "," << av_core << "," << speed << std::endl;
        }

        // 文件会在ofstream析构时自动关闭
        std::cout << "已导出 " << filename << "，共" << C1_[cases][stage].size() << "条数据" << std::endl;
      }
    }
  }




  std::deque<int> C1_detail[4][5];//实际执行的5个stage：解析任务，读table，排序，写table，整理并发回元数据改动
  std::mutex C1_detail_mutex;
  void C1_detail_append(int value,int cases,int stage){
    std::lock_guard<std::mutex> lock(C1_detail_mutex);
    C1_detail[cases][stage].push_back(value);
  }
  void MN_Report(){
    #if NEARDATACOMPACTION == 0
    printf("///Compactor is 0///\n");
    #endif
    #if NEARDATACOMPACTION == 1
    printf("///Compactor is 1///\n");
    print_C1_to_file();
    for(int i=0;i<4;i++){
      for(int j=0;j<5;j++){
        printf("Detail Work Case %d Stage %d: ",i+1,j+1);
        double avg=0.0,p1=0.0,p5=0.0,p10=0.0,p50=0.0,p90=0.0,p95=0.0,p99=0.0;
        int q_size = C1_detail[i][j].size();
        for(auto& item:C1_detail[i][j]){  
          avg += ((double)item)/q_size;
        }
        if(q_size > 0){
          std::sort(C1_detail[i][j].begin(),C1_detail[i][j].end());
          p1 = C1_detail[i][j][q_size*0.01];
          p5 = C1_detail[i][j][q_size*0.05];
          p10 = C1_detail[i][j][q_size*0.1];
          p50 = C1_detail[i][j][q_size*0.5];
          p90 = C1_detail[i][j][q_size*0.9];
          p95 = C1_detail[i][j][q_size*0.95];
          p99 = C1_detail[i][j][q_size*0.99];
        }
        if(avg>0.01) printf("avg = %d,P1 = %d,P5 = %d,P10 = %d,P50 = %d,P90 = %d,P95 = %d,P99 = %d ///\n",(int)avg,(int)p1,(int)p5,(int)p10,(int)p50,(int)p90,(int)p95,(int)p99);
        else printf("no data ///\n");
      }
    }
    printf("---- Show C1 Compaction Cost ----\n");
    #endif
    #if NEARDATACOMPACTION == 2
    printf("///Compactor is 2///\n");
    print_C1_to_file();
    for(int i=0;i<4;i++){
      for(int j=0;j<5;j++){
        printf("Detail Work Case %d Stage %d: ",i+1,j+1);
        double avg=0.0,p1=0.0,p5=0.0,p10=0.0,p50=0.0,p90=0.0,p95=0.0,p99=0.0;
        int q_size = C1_detail[i][j].size();
        for(auto& item:C1_detail[i][j]){  
          avg += ((double)item)/q_size;
        }
        if(q_size > 0){
          std::sort(C1_detail[i][j].begin(),C1_detail[i][j].end());
          p1 = C1_detail[i][j][q_size*0.01];
          p5 = C1_detail[i][j][q_size*0.05];
          p10 = C1_detail[i][j][q_size*0.1];
          p50 = C1_detail[i][j][q_size*0.5];
          p90 = C1_detail[i][j][q_size*0.9];
          p95 = C1_detail[i][j][q_size*0.95];
          p99 = C1_detail[i][j][q_size*0.99];
        }
        if(avg>0.01) printf("avg = %d,P1 = %d,P5 = %d,P10 = %d,P50 = %d,P90 = %d,P95 = %d,P99 = %d ///\n",(int)avg,(int)p1,(int)p5,(int)p10,(int)p50,(int)p90,(int)p95,(int)p99);
        else printf("no data ///\n");
      }
    }
    #endif
  }
  //LZYADD ↑
 private:
  int pr_size;
  std::unordered_map<unsigned int, std::pair<std::mutex, std::condition_variable>> imm_notifier_pool;
  unsigned int imm_temp = 1;
  std::mutex mtx_temp;
  std::condition_variable cv_temp;
  std::shared_ptr<Options> opts;
  const InternalKeyComparator internal_comparator_;
//  const InternalFilterPolicy internal_filter_policy_;

  PosixLockTable locks_;  // Thread-safe.
  Limiter mmap_limiter_;  // Thread-safe.
  Limiter fd_limiter_;    // Thread-safe.
  // Opened lazily
  WritableFile* descriptor_file;
  log::Writer* descriptor_log;
  uint64_t manifest_file_number_ = 1;
  bool usesubcompaction;
  TableCache* const table_cache_;
  std::vector<std::thread> main_comm_threads;
  ThreadPool Compactor_pool_;
  ThreadPool Message_handler_pool_;
  ThreadPool Persistency_bg_pool_;
  std::mutex versionset_mtx;
  VersionSet* versions_;
  VersionEdit_Merger ve_merger;
  std::atomic<bool> check_point_t_ready = true;
  std::mutex merger_mtx;
//  std::mutex test_compaction_mutex;
#ifndef NDEBUG
  std::atomic<size_t> debug_counter = 0;


#endif
  Status InstallCompactionResults(CompactionState* compact,
                                  std::string& client_ip);
  Status InstallCompactionResultsToComputePreparation(CompactionState* compact);
  int server_sock_connect(const char* servername, int port);
  void server_communication_thread(std::string client_ip, int socket_fd);
  void create_mr_handler(RDMA_Request* request, std::string& client_ip,
                         uint8_t target_node_id);
  void create_qp_handler(RDMA_Request* request, std::string& client_ip,
                         uint8_t target_node_id);
  void return_cpu_utilization(RDMA_Request* request, std::string& client_ip,
                         uint8_t target_node_id);
  void create_cpu_util_sender(RDMA_Request* request, std::string& client_ip,
                         uint8_t target_node_id);
  void create_cpu_util_heart_beater_sender();

  const Comparator* user_comparator() const {
    return internal_comparator_.user_comparator();
  }
  void install_version_edit_handler(RDMA_Request* request,
                                    std::string& client_ip,
                                    uint8_t target_node_id);
  void sst_garbage_collection(void* arg);

  void sst_compaction_handler(void* arg);

  void qp_reset_handler(RDMA_Request* request, std::string& client_ip,
                        int socket_fd, uint8_t target_node_id);
  void sync_option_handler(RDMA_Request* request, std::string& client_ip,
                           uint8_t target_node_id);
  void version_unpin_handler(RDMA_Request* request, std::string& client_ip);
  void Edit_sync_to_remote(VersionEdit* edit, std::string& client_ip,
                           std::unique_lock<std::mutex>* version_mtx,
                           uint8_t target_node_id);
};
}
#endif  // TimberSaw_HOME_NODE_KEEPER_H