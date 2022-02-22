
# distributed algorithms, n.dulay, 8 feb 2022
# coursework, raft consensus, v2

defmodule Database do

# d = database process state (c.f. self/this)

# _________________________________________________________ Database setters()
# 设置 sequence number/交易编号
def seqnum(d, v),      do: Map.put(d, :seqnum, v)
# 设置 余额
def balances(d, i, v), do: Map.put(d, :balances, Map.put(d.balances, i, v))

# _________________________________________________________ Database.start()
def start(config, db_num) do
  receive do
  # 收到绑定 server 的消息后，初始化 data base 的config
  { :BIND, serverP } ->
    d = %{                          # initialise database state variables
      config:   config,
      db_num:   db_num,
      serverP:  serverP,
      seqnum:   0,
      balances: Map.new,
    }
    Database.next(d)
  end # receive
end # start

# _________________________________________________________ Database.next()
def next(d) do
  receive do
  # 解析 client 请求，模式匹配(:MOVE) 和 交易操作
  { :DB_REQUEST, client_request } ->
    { :MOVE, amount, account1, account2 } = client_request.cmd

    # 自增 操作排序
    d = Database.seqnum(d, d.seqnum+1)

    # 获取余额，并更新
    balance1 = Map.get(d.balances, account1, 0)
    balance2 = Map.get(d.balances, account2, 0)
    d = Database.balances(d, account1, balance1 + amount)
    d = Database.balances(d, account2, balance2 - amount)

    # 发送给monitor审查交易，发送：数据库编号，交易编号，交易内容
    d |> Monitor.send_msg({ :DB_MOVE, d.db_num, d.seqnum, client_request.cmd })
      |> Database.send_reply_to_server(:OK)
      |> Database.next()

  unexpected ->
    Helper.node_halt(" *********** Database: unexpected message #{inspect unexpected}")
  end # receive
end # next

def send_reply_to_server(d, db_result) do
  send d.serverP, { :DB_REPLY, db_result }
  d
end # send_reply_to_server

end # Database
