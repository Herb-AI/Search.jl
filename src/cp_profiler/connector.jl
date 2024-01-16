using Sockets;

include("message.jl");

@enum NodeStatus begin
    SOLVED = 0
    FAILED = 1
    BRANCH = 2
    SKIPPED = 6
end

struct Connector
    socket::TCPSocket
    msg::Message
end

Connector() = Connector("172.31.193.91") #hostname -I

Connector(hostName::String) = Connector(hostName, 6565); #default port for cp-profiler is 6565

function Connector(hostName::String, port::Int)
    try
        socket = connect(hostName, port);
        println("Successfully connected to: " * hostName);
        return Connector(socket, Message())
    catch e
        println("Failed to connect to: " * hostName);
        println("Please run CP-Profiler first")
        throw(e)
    end
end

function close(c::Connector)
    Sockets.close(c.socket);
end

function _send_message(c::Connector)
    write(c.socket, to_bytes(c.msg));
end

function start(c::Connector, modelName::String)
    c.msg.msgType = START
    c.msg.modelName = modelName
    _send_message(c);
end

function node(c::Connector, id::Int, pid::Int, alt::Int, numberOfChildren::Int, status::NodeStatus, label::String, info::String)
    c.msg.msgType = NODE;
    c.msg.nodeId = id;
    c.msg.nodePid = pid;
    c.msg.nodeAlt = alt;
    c.msg.nodeChildren = numberOfChildren;
    c.msg.nodeStatus = Int(status);
    c.msg.nodeLabel = label;
    c.msg.nodeInfo = info;
    _send_message(c);
end

# c = Connector("172.23.232.150"); #hostname -I
# start(c, "Hello");
# node(c, 0, -1, 0, 4, BRANCH, "Label", "Info0");
# node(c, 1, 0, 0, 0, SOLVED, "Label", "SOLVED1");
# node(c, 2, 0, 1, 4, SOLVED, "Label", "SOLVED2");

#node(c, 0, -1, 0, 4, FAILED, "Label", "FAILED1");

# ----------------------------------------------------------------------------------------------------------------------

# target_byte_array = UInt8[0x1e, 0x00, 0x00, 0x00, 0x02, 0x02, 0x00, 0x00, 0x00, 0x18, 0x7b, 0x22, 0x6e, 0x61, 0x6d, 0x65, 0x22, 0x3a, 0x20, 0x22, 0x70, 0x72, 0x65, 0x6d, 0x69, 0x65, 0x72, 0x5f, 0x74, 0x65, 0x73, 0x74, 0x22, 0x7d]

# write(socket, target_byte_array);

# -----------------------------------------------------------------------------------------------------------------------

# byte_array = UInt8[0x00, 0x00, 0x00, 0x21]
# byte_array2 = UInt8[0x02, 0x02, 0x00, 0x00, 0x00, 0x1B, 0x7b, 0x22, 0x6e, 0x61, 0x6d, 0x65, 0x22, 0x3a, 0x20, 0x22, 0x6d, 0x69, 0x6e, 0x69, 0x6d, 0x61, 0x6c, 0x20, 0x65, 0x78, 0x61, 0x6d, 0x70, 0x6c, 0x65, 0x22, 0x7d]
# byte_array3 = UInt8[
#     0x00, 0x00, 0x00, 0x2B,  # message size (43)
#     0x00,  # message type (NODE)
#     0x00, 0x00, 0x00, 0x00,  # node id (0)
#     0xFF, 0xFF, 0xFF, 0xFF,  # node restart id (-1)
#     0xFF, 0xFF, 0xFF, 0xFF,  # node thread id (-1)
#     0xFF, 0xFF, 0xFF, 0xFF,  # parent id (-1)
#     0xFF, 0xFF, 0xFF, 0xFF,  # parent restart id (-1)
#     0xFF, 0xFF, 0xFF, 0xFF,  # parent thread id (-1)
#     0xFF, 0xFF, 0xFF, 0xFF,  # alternative (-1)
#     0x00, 0x00, 0x00, 0x02,  # children (2)
#     0x02,  # status (BRANCH)
#     0x00,  # field (label)
#     0x00, 0x00, 0x00, 0x04,  # string size (4)
#     0x52, 0x6F, 0x6F, 0x74  # 'Root'
# ]

#write(socket, byte_array);
#write(socket, byte_array2);
#write(socket, byte_array3);
