// Copyright (c) 2011 The LevelDB Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file. See the AUTHORS file for names of contributors.

#ifndef STORAGE_TimberSaw_DB_DB_IMPL_H_
#define STORAGE_TimberSaw_DB_DB_IMPL_H_

#include "db/dbformat.h"
#include "db/log_writer.h"
#include "db/snapshot.h"
#include <atomic>
#include <condition_variable>
#include <deque>
#include <set>
#include <string>
#include <tuple>
#include <fstream>
#include <iostream>

#include "TimberSaw/db.h"
#include "TimberSaw/env.h"

#include "port/port.h"
#include "port/thread_annotations.h"
#include "util/RPC_Process.h"
#include "util/mutexlock.h"

#include "memtable_list.h"
#include "version_set.h"

namespace TimberSaw {

class MemTable;
class TableCache;
class Version;
class VersionEdit;
class VersionSet;
class MemTableList;
//TODO: make memtableversionlist and LSM versionset 's function integrated into
// Superversion.
struct SuperVersion {
  // Accessing members of this class is not thread-safe and requires external
  // synchronization (ie db mutex held or on write thread).
  MemTable* mem;
  MemTableListVersion* imm;
  Version* current;
  // Version number of the current SuperVersion
  uint64_t version_number;
 //  std::mutex* versionset_mutex;

  // should be called outside the mutex
  SuperVersion(MemTable* new_mem, MemTableListVersion* new_imm,
               Version* new_current);
  ~SuperVersion();
  SuperVersion* Ref();
  // If Unref() returns true, Cleanup() should be called with mutex held
  // before deleting this SuperVersion.
  bool Unref();

  // call these two methods with db mutex held
  // Cleanup unrefs mem, imm and current. Also, it stores all memtables
  // that needs to be deleted in to_delete vector. Unrefing those
  // objects needs to be done in the mutex
  void Cleanup();
  void Init();

  // The value of dummy is not actually used. kSVInUse takes its address as a
  // mark in the thread local storage to indicate the SuperVersion is in use
  // by thread. This way, the value of kSVInUse is guaranteed to have no
  // conflict with SuperVersion object address and portable on different
  // platform.
  static int dummy;
  static void* const kSVInUse;
  static void* const kSVObsolete;

 private:
  std::atomic<uint32_t> refs;
  // We need to_delete because during Cleanup(), imm->Unref() returns
  // all memtables that we need to free through this vector. We then
  // delete all those memtables outside of mutex, during destruction
  autovector<MemTable*> to_delete;
};
// The structure for storing argument for thread pool.
#ifdef WITHPERSISTENCE
class DBImpl : public DB, RPC_Process {
#else
class DBImpl : public DB{
#endif
 public:
  //LZY add ↓
  int delay_num = 0;
  int delay_us_sum = 0;
  std::deque<int> delay_us;
  std::mutex delay_lock;
  void AddDelay(int us) {
    std::lock_guard<std::mutex> lock(delay_lock);
    delay_us.push_back(us);
    delay_us_sum += us;
    delay_num++;
  }
  int write_stop_num_manyImm = 0;
  int write_stop_us_sum_manyImm = 0;
  std::deque<int> write_stop_us_manyImm;
  std::mutex write_stop_lock_manyImm;
  void AddWriteStopManyImm(int us) {
    std::lock_guard<std::mutex> lock(write_stop_lock_manyImm);
    write_stop_us_manyImm.push_back(us);
    write_stop_us_sum_manyImm += us;
    write_stop_num_manyImm++;
  }
  int write_stop_num_manyL0 = 0;
  int write_stop_us_sum_manyL0 = 0;
  std::deque<int> write_stop_us_manyL0;
  std::mutex write_stop_lock_manyL0;
  void AddWriteStopManyL0(int us) {
    std::lock_guard<std::mutex> lock(write_stop_lock_manyL0);
    write_stop_us_manyL0.push_back(us);
    write_stop_us_sum_manyL0 += us;
    write_stop_num_manyL0++;
  }



  int trigger_compaction_in_level[7];
  int trivial_move_in_level[7];
  long long duration_time_in_level[7];
  unsigned compaction_size_in_level[7];

  int compaction_time_in_compute[10];
  int compaction_time_in_memory[10];
  int compaction_time_local = 0;

  int compaction_num = 0;//包括subcompaction
  int subcompaction_num = 0;
  int distribute_num = 0;

  std::deque<double> compaction_speed;
  std::deque<int> compaction_speed_sub[5];
  std::deque<int> compaction_latancy_all;
  std::mutex compaction_latancy_all_mtx;

  //double sum_time[33];
  //int sum_time_div[33];
  //double compaction_speed[35];
  //int compaction_speed_div[35];
  std::mutex insert_lat_mtx;
  std::deque<int> insert_lat;
  std::mutex get_lat_mtx;
  std::deque<int> get_lat;

  void print_insert_lat_to_file() {
      std::lock_guard<std::mutex> lock(insert_lat_mtx);
      std::ofstream insert_lat_file("../insert_lat.csv");
      if (!insert_lat_file.is_open()) {
          std::cerr << "Error: 无法打开文件 insert_lat.csv" << std::endl;
          return;
      }

      // 处理未排序数据：每100000个有效数据计算一次平均值并写入
      int aim = 300 > insert_lat.size() ? insert_lat.size() : 300;
      int gap = insert_lat.size()/aim;
      int cnt = 0;
      double sum = 0.0;  // 用于累计数据和，避免整数溢出
      for (auto& item : insert_lat) {
          if (item > 0 && item < 100000) {  // 筛选有效数据
              sum += item;
              cnt++;
              if (cnt == gap) {  // 累计到100000个有效数据
                  double avg = sum / cnt;  // 计算平均值
                  insert_lat_file << avg << std::endl;  // 写入平均值
                  sum = 0.0;  // 重置累计器
                  cnt = 0;
              }
          }
      }
      insert_lat_file.close();

      // 排序数据
      std::sort(insert_lat.begin(), insert_lat.end());
      std::ofstream insert_lat_file_sort("../insert_lat_sort.csv");
      if (!insert_lat_file_sort.is_open()) {
          std::cerr << "Error: 无法打开文件 insert_lat_sort.csv" << std::endl;
          return;
      }

      // 处理排序后数据：每1000个有效数据计算一次平均值并写入
      aim = 10000 > insert_lat.size() ? insert_lat.size() : 10000;
      gap = insert_lat.size()/aim;
      cnt = 0;
      sum = 0.0;
      for (auto& item : insert_lat) {
          if (item > 0 && item < 100000) {  // 同样筛选有效数据
              sum += item;
              cnt++;
              if (cnt == gap) {  // 累计到1000个有效数据
                  double avg = sum / cnt;  // 计算平均值
                  insert_lat_file_sort << avg << std::endl;  // 写入平均值
                  sum = 0.0;  // 重置累计器
                  cnt = 0;
              }
          }
      }
      insert_lat_file_sort.close();
  }

  std::deque<int> distribute_lat;
  std::mutex distribute_lat_mtx;

  std::deque<std::tuple<int,double,int>> C0_[4][3];//  [case][stage] -> (filenum,used_core,time)   3个stage:读Table，处理，写Table
  std::mutex C0_mutex;
  void C0_append(int filenum,double av_core,int time,int cases,int stage){
    std::lock_guard<std::mutex> lock(C0_mutex);
    C0_[cases][stage].push_back(std::make_tuple(filenum,av_core,time));
  }
  void print_C0_to_file(){
    std::lock_guard<std::mutex> lock(C0_mutex); // 确保遍历期间数据不被修改

    // 遍历所有case（0~3）和stage（0~2）
    for (int cases = 0; cases < 4; ++cases) {
      for (int stage = 0; stage < 3; ++stage) {
        // 构造文件名：C0_[case]_[stage].csv
        std::string filename = "../C0_" + std::to_string(cases+1) + "_" + std::to_string(stage+1) + ".csv";

        // 打开文件（若存在则覆盖，用trunc模式；若需追加可改为app）
        std::ofstream csv_file(filename, std::ios::app);
        if (!csv_file.is_open()) {
            std::cerr << "Error: 无法打开文件 " << filename << std::endl;
            continue; // 跳过当前文件，处理下一个
        }
        // 遍历当前[case][stage]对应的deque，写入每一行数据
        for (const auto& elem : C0_[cases][stage]) {
            int filenum = std::get<0>(elem);
            double av_core = static_cast<double>(env_->rdma_mg->rpter.numa_bind_core_num) - (std::get<1>(elem) / 100.0);
            int time = std::get<2>(elem);

            // 计算speed（处理time=0的情况）
            double speed = (filenum != 0) ? time/static_cast<double>(filenum) : 0.0;

            // 写入一行数据
            csv_file << filenum << "," << av_core << "," << speed << std::endl;
        }

        // 文件会在ofstream析构时自动关闭
        std::cout << "已导出 " << filename << "，共" << C0_[cases][stage].size() << "条数据" << std::endl;
      }
    }
  }
  std::deque<std::tuple<int,double,int>> C2_[4][5];//  [case][stage] -> (filenum,used_core,time)   5个stage:解析任务，读table，排序，写table，整理并发回元数据改动
  std::mutex C2_mutex;
  void C2_append(int filenum,double av_core,int time,int cases,int stage){
    std::lock_guard<std::mutex> lock(C2_mutex);
    C2_[cases][stage].push_back(std::make_tuple(filenum,av_core,time));
  }
  void print_C2_to_file(){
    std::lock_guard<std::mutex> lock(C2_mutex); // 确保遍历期间数据不被修改

    // 遍历所有case（0~3）和stage（0~2）
    for (int cases = 0; cases < 4; ++cases) {
      for (int stage = 0; stage < 5; ++stage) {
        // 构造文件名：C2_[case]_[stage].csv
        std::string filename = "../C2_" + std::to_string(cases+1) + "_" + std::to_string(stage+1) + ".csv";  

        // 打开文件（若存在则覆盖，用trunc模式；若需追加可改为app）
        std::ofstream csv_file(filename, std::ios::app);
        if (!csv_file.is_open()) {
            std::cerr << "Error: 无法打开文件 " << filename << std::endl;
            continue; // 跳过当前文件，处理下一个
        }
        // 遍历当前[case][stage]对应的deque，写入每一行数据
        for (const auto& elem : C2_[cases][stage]) {
            int filenum = std::get<0>(elem);
            double av_core = static_cast<double>(env_->rdma_mg->rpter.numa_bind_core_num) - std::get<1>(elem) / 100.0;
            int time = std::get<2>(elem);

            // 计算speed（处理time=0的情况）
            double speed = (filenum != 0) ? time/static_cast<double>(filenum) : 0.0;

            // 写入一行数据
            csv_file << filenum << "," << av_core << "," << speed << std::endl;
        }

        // 文件会在ofstream析构时自动关闭
        std::cout << "已导出 " << filename << "，共" << C2_[cases][stage].size() << "条数据" << std::endl;
      }
    }
  }

  
  std::deque<int> C0_s[4][3];//4个stage:读Table，处理，写Table
  std::mutex C0_s_mutex;
  void C0_append(int value,int cases,int stage){
    std::lock_guard<std::mutex> lock(C0_s_mutex);
    C0_s[cases][stage].push_back(value);
  }

  std::deque<int> C1_s[4][3];//3个stage:发送，等待处理与接收，整理元数据
  std::mutex C1_s_mutex;
  void C1_append(int value,int cases,int stage){
    std::lock_guard<std::mutex> lock(C1_s_mutex);
    C1_s[cases][stage].push_back(value);
  }
  

  std::deque<int> C2_s[4][3];//3个stage:发送，等待处理，接收
  std::mutex C2_s_mutex;
  void C2_append(int value,int cases,int stage){
    std::lock_guard<std::mutex> lock(C2_s_mutex);
    C2_s[cases][stage].push_back(value);
  }

  std::deque<int> C2_detail[4][5];//实际执行的5个stage：解析任务，读table，排序，写table，整理并发回元数据改动
  std::mutex C2_detail_mutex;
  void C2_detail_append(int value,int cases,int stage){
    std::lock_guard<std::mutex> lock(C2_detail_mutex);
    C2_detail[cases][stage].push_back(value);
  }

  void distribute_lat_append(int value){
    std::lock_guard<std::mutex> lock(distribute_lat_mtx);
    distribute_lat.push_back(value);
  }

  bool last_compaction_in_MN = true;

  void compaction_speed_append(uint64_t size,int latancy){
    std::lock_guard<std::mutex> lock(compaction_latancy_all_mtx);
    compaction_latancy_all.push_back(latancy);
    double speed = size/(latancy*1000.0); // B/ms = kB/s = 0.001MB/s
    if(10 < speed && speed < 100000) compaction_speed.push_back(speed);
  }
  void compaction_speed_append2(int sub_case,uint64_t size,int latancy){
    std::lock_guard<std::mutex> lock(compaction_latancy_all_mtx);
    compaction_latancy_all.push_back(latancy);
    double speed = size/(latancy*1000.0); // B/ms = kB/s = 0.001MB/s
    if(10.0 < speed && speed < 100000.0) compaction_speed_sub[sub_case].push_back(speed);
  }

  void insert_lat_append(int value){
    std::lock_guard<std::mutex> lock(insert_lat_mtx);
    insert_lat.push_back(value);
  }
  void get_lat_append(int value){
    std::lock_guard<std::mutex> lock(get_lat_mtx);
    get_lat.push_back(value);
  }
  void Let_MN_Report(int id){
    std::shared_ptr<RDMA_Manager> rdma_mg = env_->rdma_mg;
    RDMA_Request* send_pointer;
    ibv_mr send_mr = {};
    rdma_mg->Allocate_Local_RDMA_Slot(send_mr, Message);

    send_pointer = (RDMA_Request*)send_mr.addr;
    send_pointer->command = mn_report;
    rdma_mg->post_send<RDMA_Request>(&send_mr, id, std::string("main"));
    ibv_wc wc[2] = {};
    if (rdma_mg->poll_completion(wc, 1, std::string("main"), true,id)){
      printf("Let_MN_Report: FAIL\n");
      return;
    }
    printf("Let_MN_Report: SUCCESS\n");
  }
  // std::mutex adaptive_mtx;
  // std::mutex last_mtx;
  // bool last_compaction = true;
  // int adaptive_time = 4;
  // int add_adaptive_time(){
  //   std::lock_guard<std::mutex> lock(adaptive_mtx);
  //   adaptive_time++;
  //   if(adaptive_time>4) adaptive_time = 0;
  //   return adaptive_time;
  // }
  // void zero_adaptive_time(){
  //   std::lock_guard<std::mutex> lock(adaptive_mtx);
  //   adaptive_time = 0;
  // }
  // void change_last(){
  //   std::lock_guard<std::mutex> lock(last_mtx);
  //   last_compaction = ~last_compaction;
  // }
  virtual void DBreport() override{
    //LZY add ↓
    printf("-----DBImpl->DBreport-----\n");
    #ifdef MYDEBUG
    for(int i=0;i<=5;i++){
      duration_time_in_level[i] = duration_time_in_level[i]/1000;
      printf("///level %d has %d compactions and %d trival move\n\tcompaction keeps %lld s, with %u MB///\n",
        i,trigger_compaction_in_level[i],trivial_move_in_level[i],duration_time_in_level[i],compaction_size_in_level[i]);
    }
    #if NEARDATACOMPACTION == 0
    printf("///Compactor is 0///\n");
    printf("---- Show C0 Compaction Cost ----\n");
    print_C0_to_file();
    for(int i=0;i<4;i++){
      for(int j=0;j<3;j++){
        printf("For Case %d Stage %d: ",i+1,j+1);
        double avg=0.0,p1=0.0,p5=0.0,p10=0.0,p50=0.0,p90=0.0,p95=0.0,p99=0.0;
        int q_size = C0_s[i][j].size();
        for(auto& item:C0_s[i][j]){
          avg += ((double)item)/q_size;
        }
        if(q_size > 0){
          std::sort(C0_s[i][j].begin(),C0_s[i][j].end());
          p1 = C0_s[i][j][q_size*0.01];
          p5 = C0_s[i][j][q_size*0.05];
          p10 = C0_s[i][j][q_size*0.1];
          p50 = C0_s[i][j][q_size*0.5];
          p90 = C0_s[i][j][q_size*0.9];
          p95 = C0_s[i][j][q_size*0.95];
          p99 = C0_s[i][j][q_size*0.99];
        }
        if(avg>0.01) printf("avg = %d,P1 = %d,P5 = %d,P10 = %d,P50 = %d,P90 = %d,P95 = %d,P99 = %d ///\n",(int)avg,(int)p1,(int)p5,(int)p10,(int)p50,(int)p90,(int)p95,(int)p99);
        else printf("no data ///\n");
      }
    }
    #endif
    #if NEARDATACOMPACTION == 1
    printf("///Compactor is 1///\n");
    printf("---- Show C1 Compaction Cost ----\n");
    for(int i=0;i<4;i++){
      for(int j=0;j<3;j++){
        printf("For Case %d Stage %d: ",i+1,j+1);
        double avg=0.0,p1=0.0,p5=0.0,p10=0.0,p50=0.0,p90=0.0,p95=0.0,p99=0.0;
        int q_size = C1_s[i][j].size();
        for(auto& item:C1_s[i][j]){
          avg += ((double)item)/q_size;
        }
        if(q_size > 0){
          std::sort(C1_s[i][j].begin(),C1_s[i][j].end());
          p1 = C1_s[i][j][q_size*0.01];
          p5 = C1_s[i][j][q_size*0.05];
          p10 = C1_s[i][j][q_size*0.1];
          p50 = C1_s[i][j][q_size*0.5];
          p90 = C1_s[i][j][q_size*0.9];
          p95 = C1_s[i][j][q_size*0.95];
          p99 = C1_s[i][j][q_size*0.99];
        }
        if(avg>0.01) printf("avg = %d,P1 = %d,P5 = %d,P10 = %d,P50 = %d,P90 = %d,P95 = %d,P99 = %d ///\n",(int)avg,(int)p1,(int)p5,(int)p10,(int)p50,(int)p90,(int)p95,(int)p99);
        else printf("no data ///\n");
      }
    }
    #endif
    #if NEARDATACOMPACTION == 2
    printf("///Compactor is 2///\n");
    printf("---- Show C2 Compaction Cost ----\n");
    print_C2_to_file();
    for(int i=0;i<4;i++){
      for(int j=0;j<3;j++){
        printf("For Case %d Stage %d: ",i+1,j+1);
        double avg=0.0,p1=0.0,p5=0.0,p10=0.0,p50=0.0,p90=0.0,p95=0.0,p99=0.0;
        int q_size = C2_s[i][j].size();
        for(auto& item:C2_s[i][j]){
          avg += ((double)item)/q_size;
        }
        if(q_size > 0){
          std::sort(C2_s[i][j].begin(),C2_s[i][j].end());
          p1 = C2_s[i][j][q_size*0.01];
          p5 = C2_s[i][j][q_size*0.05];
          p10 = C2_s[i][j][q_size*0.1];
          p50 = C2_s[i][j][q_size*0.5];
          p90 = C2_s[i][j][q_size*0.9];
          p95 = C2_s[i][j][q_size*0.95];
          p99 = C2_s[i][j][q_size*0.99];
        }
        if(avg>0.01) printf("avg = %d,P1 = %d,P5 = %d,P10 = %d,P50 = %d,P90 = %d,P95 = %d,P99 = %d ///\n",(int)avg,(int)p1,(int)p5,(int)p10,(int)p50,(int)p90,(int)p95,(int)p99);
        else printf("no data ///\n");
      }
    }
    for(int i=0;i<4;i++){
      for(int j=0;j<5;j++){
        printf("Detail Work Case %d Stage %d: ",i+1,j+1);
        double avg=0.0,p1=0.0,p5=0.0,p10=0.0,p50=0.0,p90=0.0,p95=0.0,p99=0.0;
        int q_size = C2_detail[i][j].size();
        for(auto& item:C2_detail[i][j]){  
          avg += ((double)item)/q_size;
        }
        if(q_size > 0){
          std::sort(C2_detail[i][j].begin(),C2_detail[i][j].end());
          p1 = C2_detail[i][j][q_size*0.01];
          p5 = C2_detail[i][j][q_size*0.05];
          p10 = C2_detail[i][j][q_size*0.1];
          p50 = C2_detail[i][j][q_size*0.5];
          p90 = C2_detail[i][j][q_size*0.9];
          p95 = C2_detail[i][j][q_size*0.95];
          p99 = C2_detail[i][j][q_size*0.99];
        }
        if(avg>0.01) printf("avg = %d,P1 = %d,P5 = %d,P10 = %d,P50 = %d,P90 = %d,P95 = %d,P99 = %d ///\n",(int)avg,(int)p1,(int)p5,(int)p10,(int)p50,(int)p90,(int)p95,(int)p99);
        else printf("no data ///\n");
      }
    }
    printf("---- Show Compaction Time ----\n");
    printf("Compaction Time: Local = %d\n",compaction_time_local);
    printf("In MN:\n");
    for(int i=0;i<10;i+=2){
      if(compaction_time_in_memory[i]==0) continue;
      printf("\tMN Compaction Time: Node %d = %d\n",i,compaction_time_in_memory[i]);
    }
    printf("In CN:\n");
    for(int i=1;i<10;i+=2){
      if(compaction_time_in_compute[i]==0 || i == env_->rdma_mg->node_id) continue;
      printf("\tCN Compaction Time: Node %d = %d\n",i,compaction_time_in_compute[i]);
    }
    printf("---- End Show Compaction Time ----\n");
    #endif
    env_->rdma_mg->print_uti();
    #endif

    #ifdef CHECK_INSERT_LAT 
    printf("---- Show OPT Latancy ----\n"); 
    if(!insert_lat.empty()){
      print_insert_lat_to_file();
      std::sort(insert_lat.begin(),insert_lat.end());
      double avg = 0.0;
      int q_size = insert_lat.size();
      for(auto& item:insert_lat){
        avg += ((double)item)/q_size;
      }
      int p50 = insert_lat[insert_lat.size()*0.5];
      int p90 = insert_lat[insert_lat.size()*0.9];
      int p99 = insert_lat[insert_lat.size()*0.99];
      //int p999 = insert_lat[insert_lat.size()*0.999];
      printf("///insert latancy:avg = %d,P50 = %d,P90 = %d,P99 = %d ///\n",(int)avg,p50,p90,p99);
    }
    if(!get_lat.empty()){
      std::sort(get_lat.begin(),get_lat.end());
      double avg = 0.0;
      int q_size = get_lat.size();
      for(auto& item:get_lat){
        avg += ((double)item)/q_size;
      }
      int p50 = get_lat[get_lat.size()*0.5];
      int p90 = get_lat[get_lat.size()*0.9];
      int p99 = get_lat[get_lat.size()*0.99];
      //int p999 = get_lat[get_lat.size()*0.999];
      printf("///get latancy:avg = %d,P50 = %d,P90 = %d,P99 = %d ///\n",(int)avg,p50,p90,p99);
    }
    printf("---- End Show OPT Latancy ----\n");
    #endif
    printf("---- Show Write Delay And Stop ----\n");
    printf("Write Delay:happen time = %d\n",delay_num);
    if(write_stop_num_manyImm>0){
      std::sort(write_stop_us_manyImm.begin(),write_stop_us_manyImm.end());
      int p50 = write_stop_us_manyImm[write_stop_us_manyImm.size()*0.5];
      int p90 = write_stop_us_manyImm[write_stop_us_manyImm.size()*0.9];
      int p99 = write_stop_us_manyImm[write_stop_us_manyImm.size()*0.99];
      printf("Write Stop By Too Many Immutable Table :happen time = %d, avg = %d us,P50 = %d,P90 = %d,P99 = %d\n",write_stop_num_manyImm,write_stop_us_sum_manyImm/write_stop_num_manyImm,p50,p90,p99);
    }else{
      printf("Write Stop By Too Many Immutable Table :happen time = 0, avg = 0 us,P50 = 0,P90 = 0,P99 = 0\n");
    }
    if(write_stop_num_manyL0>0){
      std::sort(write_stop_us_manyL0.begin(),write_stop_us_manyL0.end());
      int p50 = write_stop_us_manyL0[write_stop_us_manyL0.size()*0.5];
      int p90 = write_stop_us_manyL0[write_stop_us_manyL0.size()*0.9];
      int p99 = write_stop_us_manyL0[write_stop_us_manyL0.size()*0.99];
      printf("Write Stop By Too Many L0 Table :happen time = %d, avg = %d us,P50 = %d,P90 = %d,P99 = %d\n",write_stop_num_manyL0,write_stop_us_sum_manyL0/write_stop_num_manyL0,p50,p90,p99);
    }else{
      printf("Write Stop By Too Many L0 Table :happen time = 0, avg = 0 us,P50 = 0,P90 = 0,P99 = 0\n");
    }
    if(write_stop_num_manyL0>0)
    printf("---- Show Compaction Latancy ----\n");
    if(!compaction_latancy_all.empty()){
      std::sort(compaction_latancy_all.begin(),compaction_latancy_all.end());
      double avg = 0.0;
      int q_size = compaction_latancy_all.size();
      for(auto& item:compaction_latancy_all){
        avg += ((double)item)/q_size;
      }
      int p50 = compaction_latancy_all[q_size*0.5];
      int p90 = compaction_latancy_all[q_size*0.9];
      int p99 = compaction_latancy_all[q_size*0.99];
      //int p999 = compaction_latancy_all[q_size*0.999];
      printf("///compaction latancy:avg = %d,P50 = %d,P90 = %d,P99 = %d ///\n",(int)avg,p50,p90,p99);
    }
    // if(!distribute_lat.empty()){
    //   std::sort(distribute_lat.begin(),distribute_lat.end());
    //   double avg = 0.0;
    //   int q_size = distribute_lat.size();
    //   for(auto& item:distribute_lat){
    //     avg += ((double)item)/q_size;
    //   }
    //   printf("///Distribute cost:avg = %d us///\n",(int)avg);
    // }
    printf("---- End Show Compaction Latancy ----\n");
    
    // printf("---- Show Compaction Speed ----\n");
    // if(!compaction_speed.empty()){
    //   double avg = 0.0;
    //   int q_size = compaction_speed.size();
    //   printf("///compaction speed size = %d ///\n",q_size);
    //   for(auto& item:compaction_speed){
    //     if(item<10||item>100000) printf("%d?????\n",item);
    //     avg += item/q_size;
    //   }
    //   printf("///compaction speed:avg = %lf MB/s ///\n",avg);
    // }
    // printf("---- End Show Compaction Speed ----\n");
    printf("---- Show Compaction Speed ----\n");
    if(!compaction_speed_sub[1].empty()){
      double avg = 0.0;
      int q_size = compaction_speed_sub[1].size();
      printf("///compaction speed size = %d ///\n",q_size);
      for(auto& item:compaction_speed_sub[1]){
        if(item<10||item>100000) printf("%d?????\n",item);
        avg += item/q_size;
      }
      printf("///compaction speed case1:avg = %lf MB/s ///\n",avg);
    }
    if(!compaction_speed_sub[2].empty()){
      double avg = 0.0;
      int q_size = compaction_speed_sub[2].size();
      printf("///compaction speed size = %d ///\n",q_size);
      for(auto& item:compaction_speed_sub[2]){
        if(item<10||item>100000) printf("%d?????\n",item);
        avg += item/q_size;
      }
      printf("///compaction speed case2:avg = %lf MB/s ///\n",avg);
    }
    if(!compaction_speed_sub[3].empty()){
      double avg = 0.0;
      int q_size = compaction_speed_sub[3].size();
      printf("///compaction speed size = %d ///\n",q_size);
      for(auto& item:compaction_speed_sub[3]){
        if(item<10||item>100000) printf("%d?????\n",item);
        avg += item/q_size;
      }
      printf("///compaction speed case3:avg = %lf MB/s ///\n",avg);
    }
    if(!compaction_speed_sub[4].empty()){
      double avg = 0.0;
      int q_size = compaction_speed_sub[4].size();
      printf("///compaction speed size = %d ///\n",q_size);
      for(auto& item:compaction_speed_sub[4]){
        if(item<10||item>100000) printf("%d?????\n",item);
        avg += item/q_size;
      }
      printf("///compaction speed case4:avg = %lf MB/s ///\n",avg);
    }
    printf("---- End Show Compaction Speed ----\n");
    #ifdef CHECK_COMPACTION_TIME  
    // for(int i=0;i<=32;i++){
    //   printf("///when less than %d.5 avaliable core, speed %lf MB/s ///\n",i,1000.0*compaction_speed_div[i]/compaction_speed[i]);
    // }
    #endif  
    std::fflush(stdout);
    //LZY add ↑
  }
  //LZY add ↑
  DBImpl(const Options& options, const std::string& dbname);
  DBImpl(const Options& raw_options, const std::string& dbname,
         const std::string ub, const std::string lb);
  DBImpl(const DBImpl&) = delete;
  DBImpl& operator=(const DBImpl&) = delete;

  ~DBImpl() override;
  // Chuqing: Dbimpl外可以封装一层sharding那个文件里的
  // Implementations of the DB interface
  Status Put(const WriteOptions&, const Slice& key,
             const Slice& value) override;
  Status Delete(const WriteOptions&, const Slice& key) override;
  Status Write(const WriteOptions& options, WriteBatch* updates) override;
  Status Get(const ReadOptions& options, const Slice& key,
             std::string* value) override;
  Iterator* NewIterator(const ReadOptions&) override;
//#ifdef BYTEADDRESSABLE
//  Iterator* NewSEQIterator(const ReadOptions&) override;
//#endif
  const Snapshot* GetSnapshot() override;
  void ReleaseSnapshot(const Snapshot* snapshot) override;
  // Chuqing: 
  bool GetProperty(const Slice& property, std::string* value) override;
  void GetApproximateSizes(const Range* range, int n, uint64_t* sizes) override;
  void CompactRange(const Slice* begin, const Slice* end) override;

  // Extra methods (for testing) that are not in the public DB interface

  // Compact any files in the named level that overlap [*begin,*end]
  void TEST_CompactRange(int level, const Slice* begin, const Slice* end);

  // Force current memtable contents to be compacted.
//  Status TEST_CompactMemTable();

  // Return an internal iterator over the current state of the database.
  // The keys of this iterator are internal keys (see format.h).
  // The returned iterator should be deleted when no longer needed.
  Iterator* TEST_NewInternalIterator();

  // Return the maximum overlapping data (in bytes) at next level for any
  // file at a level >= 1.
  int64_t TEST_MaxNextLevelOverlappingBytes();

  // Record a sample of bytes read at the specified internal key.
  // Samples are taken approximately once every config::kReadBytesPeriod
  // bytes.
  void RecordReadSample(Slice key);
  void CleanupSuperVersion(SuperVersion* sv);
  void ReturnAndCleanupSuperVersion(SuperVersion* sv);
  SuperVersion* GetThreadLocalSuperVersion();
  bool ReturnThreadLocalSuperVersion(SuperVersion* sv);
  void ResetThreadLocalSuperVersions();
  void InstallSuperVersion();
  void WaitforAllbgtasks(bool clear_mem) override;
  void SetTargetnodeid(uint8_t id){
    shard_target_node_id = id;
//    imm_.SetTargetnodeid(id);
  }
  // TODO: If there are two shards connected to the same memory node, what shall we
  // we do?
  void client_message_polling_and_handling_thread(std::string q_id);
  void WaitForComputeMessageHandlingThread(uint8_t target_memory_id,
                                              uint8_t shard_id_);
  std::string upper_bound;
  std::string lower_bound;
  // long double server_cpu_percent = 0.0;
//  void Wait_for_client_message_hanlding_setup();
 private:
  friend class RDMA_Manager;
  friend class Env;
  friend class DB;
//  struct CompactionState;
//  struct SubcompactionState;
  struct Writer;

  // Information for a manual compaction
  struct ManualCompaction {
    int level;
    bool done;
    const InternalKey* begin;  // null means beginning of key range
    const InternalKey* end;    // null means end of key range
    InternalKey tmp_storage;   // Used to keep track of compaction progress
  };
//LZY add v
  void AddCompactionThread();
  void SubCompactionThread();
  void AddLocalCompactionThread();
  void SubLocalCompactionThread();
  void QuickAddLocalCompactionThread();
  void QuickSubLocalCompactionThread();
//LZY add ^


  Iterator* NewInternalIterator(const ReadOptions&,
                                SequenceNumber* latest_snapshot,
                                uint32_t* seed);
//#ifdef BYTEADDRESSABLE
//  Iterator* NewInternalSEQIterator(const ReadOptions&,
//                                SequenceNumber* latest_snapshot,
//                                uint32_t* seed);
//#endif
  Status NewDB();

  // Recover the descriptor from persistent storage.  May do a significant
  // amount of work to recover recently logged updates.  Any changes to
  // be made to the descriptor are added to *edit.
  Status Recover(VersionEdit* edit, bool* save_manifest)
      EXCLUSIVE_LOCKS_REQUIRED(undefine_mutex);

  void MaybeIgnoreError(Status* s) const;

  // Delete any unneeded files and stale in-memory entries.
  void RemoveObsoleteFiles() EXCLUSIVE_LOCKS_REQUIRED(undefine_mutex);

  // Compact the in-memory write buffer to disk.  Switches to a new
  // log-file/memtable and writes a new descriptor iff successful.
  // Errors are recorded in bg_error_.
  void CompactMemTable();
  void ForceCompactMemTable();
  Status RecoverLogFile(uint64_t log_number, bool last_log, bool* save_manifest,
                        VersionEdit* edit, SequenceNumber* max_sequence)
      EXCLUSIVE_LOCKS_REQUIRED(undefine_mutex);

  Status WriteLevel0Table(FlushJob* job, VersionEdit* edit)
      EXCLUSIVE_LOCKS_REQUIRED(undefine_mutex);
  Status WriteLevel0Table(MemTable* job, VersionEdit* edit, Version* base)
  EXCLUSIVE_LOCKS_REQUIRED(undefine_mutex);
  Status PickupTableToWrite(bool force, uint64_t seq_num, MemTable*& mem_r)
      EXCLUSIVE_LOCKS_REQUIRED(undefine_mutex);
  WriteBatch* BuildBatchGroup(Writer** last_writer)
      EXCLUSIVE_LOCKS_REQUIRED(undefine_mutex);

  void RecordBackgroundError(const Status& s);

  void MaybeScheduleFlushOrCompaction() EXCLUSIVE_LOCKS_REQUIRED(undefine_mutex);
  static void BGWork_Flush(void* thread_args);
  static void BGWork_Compaction(void* thread_args);
  static void BGWork_Offloader(void* thread_args);
  void Other_Compaction_Handler1(void* arg);//LZYADD
  void Other_Compaction_Handler2(void* arg);//LZYADD
  void Other_Compaction_Handler3(void* arg);//LZYADD
  static void BGWork_CompactionOthers(void* thread_args);//LZYADD
  Status DoRemoteCompactionWork(CompactionState* compact,uint8_t target_node_id) EXCLUSIVE_LOCKS_REQUIRED(undefine_mutex); //LZYADD 
  Status DoRemoteCompactionWork2(CompactionState* compact,uint8_t target_node_id) EXCLUSIVE_LOCKS_REQUIRED(undefine_mutex); //LZYADD 
  Status DoRemoteCompactionWork3(CompactionState* compact,uint8_t target_node_id,uint64_t start_num) EXCLUSIVE_LOCKS_REQUIRED(undefine_mutex); //LZYADD 
  Status DoRemoteCompactionWorkWithSubcompaction(CompactionState* compact,uint8_t target_node_id,uint64_t start_num);//LZYADD
  void BackgroundCall();
  void BackgroundFlush(void* p);
  void BackgroundCompaction(void* p) EXCLUSIVE_LOCKS_REQUIRED(undefine_mutex);
  void BackgroundCompactionOrDistribute(void *p) EXCLUSIVE_LOCKS_REQUIRED(undefine_mutex);//LZYADD
  std::atomic<int> print_counter = 0;
  int CompactionTaskWhereToGo(Compaction* compact);//LZYADD
  int CompactionTaskWhereToGoMod3(Compaction* compact);//LZYADD
  int CompactionTaskWhereToGoPureRemote(Compaction* compact);//LZYADD
  int CompactionTaskWhereToGoTestv0(Compaction* compact);//LZYADD
  int CompactionTaskWhereToGoTestv1(Compaction* compact);//LZYADD
  int CompactionTaskWhereToGoTestv2(Compaction* compact);//LZYADD
  int CompactionTaskWhereToGoTestv3(Compaction* compact);//LZYADD 当前最优
  int CompactionTaskWhereToGoTestv4(Compaction* compact);//LZYADD
  int CompactionTaskWhereToGoTestv5(Compaction* compact);//LZYADD
  bool CheckWhetherPushDownorNot(Compaction* compact);
  bool CheckByteaddressableOrNot(Compaction* compact);
  long double RequestRemoteUtilization();
//  void ActivateRemoteCPURefresh();
  void CleanupCompaction(CompactionState* compact)
      EXCLUSIVE_LOCKS_REQUIRED(undefine_mutex);
  Status DoCompactionWork(CompactionState* compact)
      EXCLUSIVE_LOCKS_REQUIRED(undefine_mutex);
  void ProcessKeyValueCompaction(SubcompactionState* sub_compact);
  void ProcessKeyValueCompactionPlusCases(SubcompactionState* sub_compact,int cases);//LZYADD
  void RemoteProcessKeyValueCompaction(SubcompactionState* sub_compact,uint8_t target_node_id,std::atomic<uint64_t>* file_num);//LZYADD
  void RemoteProcessKeyValueCompactionPlusCases(SubcompactionState* sub_compact,uint8_t target_node_id,std::atomic<uint64_t>* file_num,int cases);//LZYADD
  //TODO: We could probably use corotine to do the compaction because the compaction for
  // large key value size can have large cpu stall time for memroy copy.
  Status DoCompactionWorkWithSubcompaction(CompactionState* compact);
  Status OpenCompactionOutputFileFor(CompactionState* compact,uint8_t target_node_id);//LZYADD
  Status OpenCompactionOutputFile(SubcompactionState* compact);
  Status OpenCompactionOutputFileFor3(SubcompactionState* compact,uint64_t file_num);//LZYADD
  Status OpenCompactionOutputFile(CompactionState* compact);
  Status OpenCompactionOutputFile3(CompactionState* compact,uint64_t start_num);//LZYADD
  Status FinishCompactionOutputFile(SubcompactionState* compact,
                                    Iterator* input);
  Status FinishCompactionOutputFile(CompactionState* compact, Iterator* input);
  
  Status InstallCompactionResults(CompactionState* compact,
                                  std::unique_lock<std::mutex>* lck_sv)
      EXCLUSIVE_LOCKS_REQUIRED(undefine_mutex);
  Status InstallCompactionResultsSelf(CompactionState* compact,std::unique_lock<std::mutex>* lck_sv);//LZYADD
  Status InstallCompactionResultsRemote(CompactionState* compact,std::unique_lock<std::mutex>* lck_sv,uint8_t target_node_id);//LZYADD
  Status InstallCompactionResultsFor(CompactionState* compact,uint8_t target_node_id);//LZYADD
  Status TryInstallMemtableFlushResults(
      FlushJob* job, VersionSet* vset,
      std::shared_ptr<RemoteMemTableMetaData>& sstable, VersionEdit* edit);
//  SuperVersion* GetReferencedSuperVersion(DBImpl* db);
  void NearDataCompaction(Compaction* c);
  void LocalCompaction(Compaction* c);
  void RemoteDataCompaction(Compaction* c,uint8_t target_node_id);//LZYADD
//  void Communication_To_Home_Node();
  void Edit_sync_to_remote(VersionEdit* edit, uint8_t target_node_id);
  const Comparator* user_comparator() const {
    return internal_comparator_.user_comparator();
  }
  void sync_option_to_remote(uint8_t target_node_id);
  void remote_qp_reset(std::string& qp_type, uint8_t target_node_id);
  void install_version_edit_handler(RDMA_Request* request, std::string client_ip);
#ifdef WITHPERSISTENCE
  static void SSTable_Unpin_Dispatch(void* thread_args);
  void persistence_unpin_handler(void* arg);
#endif
  // Constant after construction
  Env* const env_; //实际使用PosixEnv
  std::unordered_map<unsigned int, std::pair<std::mutex, std::condition_variable>> imm_notifier_pool;
//  unsigned int imm_temp = 1;
  // THose vairbale could be shared pointers from the out side.
  std::mutex* mtx_imme;
  std::atomic<uint32_t>* imm_gen;
  uint32_t* imme_data;
  uint32_t* byte_len;
  std::condition_variable* cv_imme;

  //LZYADD ↓
  std::unordered_map<uint8_t, std::mutex*> CN_mtx_imme;
  std::unordered_map<uint8_t,  std::atomic<uint32_t>*> CN_imm_gen;
  std::unordered_map<uint8_t, uint32_t*> CN_imme_data;
  std::unordered_map<uint8_t, uint32_t*> CN_byte_len;
  std::unordered_map<uint8_t, std::condition_variable*> CN_cv_imme;
  //LZYADD ↑


  const InternalKeyComparator internal_comparator_;
  const InternalFilterPolicy internal_filter_policy_;
  Options options_;  // options_.comparator == &internal_comparator_
  const bool owns_info_log_;
  const bool owns_cache_;
  const std::string dbname_;

  // table_cache_ provides its own synchronization
  TableCache* const table_cache_;
  int byte_addressable_boundary= -1;
  // Lock over the persistent DB state.  Non-null iff successfully acquired.
  FileLock* db_lock_;
  std::atomic<bool> mem_switching;
  int thread_ready_num;
  // State below is protected by undefine_mutex
  // we could rename it as superversion mutex
  port::Mutex undefine_mutex;

//  port::Mutex write_stall_mutex_;
//  SpinMutex spin_memtable_switch_mutex;
  std::atomic<bool> shutting_down_;
  std::condition_variable write_stall_cv;
  int main_comm_thread_ready_num = 0;
  std::mutex FlushPickMTX;
  // THE Mutex will protect both memlist and the superversion pointer.
  std::mutex superversion_memlist_mtx;
  // TODO: use read write lock to control the version set mtx.
//  std::mutex versionset_mtx;
  bool locked = false;
//  bool check_and_clear_pending_recvWR = false;
//  SpinMutex LSMv_mtx;
  std::atomic<MemTable*> mem_;
//  std::atomic<MemTable*> imm_;  // Memtable being compacted
  MemTableList imm_;
  std::atomic<bool> has_imm_;         // So bg thread can detect non-null imm_
  WritableFile* logfile_;
  uint64_t logfile_number_;
  log::Writer* log_;
  std::mutex log_mtx;
  std::atomic<size_t> put_counter = 0;
  uint32_t seed_;  // For sampling.

  // Queue of writers.
  std::deque<Writer*> writers_;
  WriteBatch* tmp_batch_;

  SnapshotList snapshots_;
  ThreadPool Unpin_bg_pool_;
  // Set of table files to protect from deletion because they are
  // part of ongoing compactions.
//  std::set<uint64_t> pending_outputs_;

  // Has a background compaction been scheduled or is running?
  bool background_compaction_scheduled_;

  ManualCompaction* manual_compaction_;
  std::atomic<bool> slow_down_compaction = false;
  VersionSet* const versions_;
//  std::map<Slice, VersionSet*, cmpBySlice> const versions_pool;
  // Have we encountered a background error in paranoid mode?
  Status bg_error_;

  CompactionStats stats_[config::kNumLevels];
//  std::atomic<size_t> memtable_counter = 0;
//  std::atomic<size_t> kv_counter0 = 0;
//  std::atomic<size_t> kv_counter1 = 0;
  std::atomic<uint64_t> super_version_number_;
  SuperVersion* super_version;
//  std::unique_ptr<ThreadLocalPtr> local_sv_;
  ThreadLocalPtr* local_sv_;
  std::vector<std::thread> main_comm_threads;
  uint8_t shard_target_node_id = 0;
  uint8_t shard_id = 0;
  std::atomic<bool> level_0_compaction_in_progress = false;
  // Add for cpu utilization refreshing
  //TODO: (chuqing) if multiple servers
//  long double server_cpu_percent = 0.0;
//  std::map<uint16_t,uint16_t> remote_core_number_map;
//  std::map<uint16_t,uint16_t> compute_core_number_map;
  //TODO(chuqing): add for count time, need a better calculator
  long int accumulated_time = 0;

#ifdef PROCESSANALYSIS
  std::atomic<size_t> Total_time_elapse;
  std::atomic<size_t> flush_times;
#endif

};

// Sanitize db options.  The caller should delete result.info_log if
// it is not equal to src.info_log.
Options SanitizeOptions(const std::string& db,
                        const InternalKeyComparator* icmp,
                        const InternalFilterPolicy* ipolicy,
                        const Options& src);

}  // namespace TimberSaw

#endif  // STORAGE_TimberSaw_DB_DB_IMPL_H_
