
# distributed algorithms, n.dulay, 8 feb 2022
# coursework, raft consensus, v2

defmodule Raft do

# _________________________________________________________ Raft.start/0
def start do
  config = Configuration.node_init()
  Raft.start(config, config.start_function)
end # start/0

# _________________________________________________________ Raft.start/2
def start(_config, :cluster_wait), do: :skip
def start(config,  :cluster_start) do
  # more initialisations
  # 管道调用，将config作为第一个参数传入 .node_info() 【添加 node_type, node_num, node_name等键】
  # 开启一个Monitor进程，并将pid 存入键 :monitorP 中
  config = config
    |> Configuration.node_info("Raft")
    |> Map.put(:monitorP, spawn(Monitor, :start, [config]))
  # 等价于：
  # config = Configuration.node_info(config, "Raft")
  # config = Map.put(config, :monitorP, spawn(Monitor, :start, [config]))

  ############################################################
  ##      创建 Server节点，并绑定与之对应的 Database 进程        ##
  ############################################################
  # create 1 database and 1 raft server in each server-node
  servers = for num <- 1 .. config.n_servers do
    Node.spawn(:'server#{num}_#{config.node_suffix}', Server, :start, [config, num])
  end # for

  databases = for num <- 1 .. config.n_servers do
    Node.spawn(:'server#{num}_#{config.node_suffix}', Database, :start, [config, num])
  end # for

  # bind servers and databases
  for num <- 0 .. config.n_servers-1 do
    serverP   = Enum.at(servers, num)
    databaseP = Enum.at(databases, num)
    send serverP,   { :BIND, servers, databaseP }
    send databaseP, { :BIND, serverP }
  end # for

  ############################################################
  ##        创建 Client节点，并传入 Servers进程id的列表         ##
  ############################################################
  # create 1 client in each client_node and bind to servers
  for num <- 1 .. config.n_clients do
    Node.spawn(:'client#{num}_#{config.node_suffix}', Client, :start, [config, num, servers])
  end # for

end # start

end # Raft
