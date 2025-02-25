#include <fstream>
#include <iostream>
#include <memory_node/memory_node_keeper.h>

#include "util/rdma.h"

//namespace TimberSaw{
int main(int argc,char* argv[])
{
  TimberSaw::Memory_Node_Keeper* mn_keeper;

  if (argc == 4){
    uint32_t tcp_port;
    int pr_size;
    int Memory_server_id;
    char* value = argv[1];
    std::stringstream strValue1;
    strValue1 << value;
    strValue1 >> tcp_port;
    value = argv[2];
    std::stringstream strValue2;
    //  strValue.str("");
    strValue2 << value;
    strValue2 >> pr_size;
    value = argv[3];
    std::stringstream strValue3;
    //  strValue.str("");
    strValue3 << value;
    strValue3 >> Memory_server_id;
     mn_keeper = new TimberSaw::Memory_Node_Keeper(true, tcp_port, pr_size);
     TimberSaw::RDMA_Manager::node_id = 2 * Memory_server_id;
  }else{
    mn_keeper = new TimberSaw::Memory_Node_Keeper(true, 19843, 88);
    TimberSaw::RDMA_Manager::node_id = 0;
  }
  mn_keeper->set_usesubcompaction(mn_keeper->get_opt()->usesubcompaction);//LZY add 否则需要在初始化时独立设置
  mn_keeper->SetBackgroundThreads(mn_keeper->get_opt()->max_memory_compactions, TimberSaw::ThreadPoolType::CompactionThreadPool);
//  std::thread CPU_utilization_heartbeat([&](){
//    // std::ofstream myfile;
//    while (1){
//      std::this_thread::sleep_for(std::chrono::milliseconds(CPU_UTILIZATION_CACULATE_INTERVAL));
//      long double new_percent = TimberSaw::Memory_Node_Keeper::rdma_mg->rpter.getCurrentValue();
//      sleep(2);
////      printf("CPU utilization is %Lf\n", TimberSaw::Memory_Node_Keeper::rdma_mg->rpter.getCurrentValue());
//    }
//  });
//  CPU_utilization_heartbeat.detach();
  mn_keeper->Server_to_Client_Communication();

  delete mn_keeper;

  return 0;
}