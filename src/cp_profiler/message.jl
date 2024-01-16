using Sockets;

@enum MsgType begin
	NODE = 0
	DONE = 1
	START = 2
    RESTART = 3
end

@enum OptionalArgs begin
    LABEL = 0
    NOGOOD = 1
    INFO = 2
end

mutable struct Message
    msgType::MsgType
    restartId::Int
    nodeId::Int
    nodePid::Int
    nodeAlt::Int
    nodeChildren::Int
    nodeStatus::Int
    nodeLabel::String
    nodeNoGood::String
    nodeInfo::String
    modelName::String
end

Message() = Message(START, 0, 0, 0, 0, 0, 0, "", "", "", "Test");

function Base.show(io::IO, msg::Message)
    println("Message {")
    println("    msgType =      " * string(Symbol(msg.msgType)) * ",")
    println("    restartId =    " * string(msg.restartId) * ",")
    println("    nodeId =       " * string(msg.nodeId) * ",")
    println("    nodePid =      " * string(msg.nodePid) * ",")
    println("    nodeAlt =      " * string(msg.nodeAlt) * ",")
    println("    nodeChildren = " * string(msg.nodeChildren) * ",")
    println("    nodeStatus =   " * string(msg.nodeStatus) * ",")
    println("    nodeLabel =    " * msg.nodeLabel * ",")
    println("    nodeNoGood =   " * msg.nodeNoGood * ",")
    println("    nodeInfo =     " * msg.nodeInfo * ",")
    println("    modelName =    " * msg.modelName)
    println("}")
end

function clear!(msg::Message)
    msg.msgType = NODE
    msg.nodeId = 0
    msg.nodePid = 0
    msg.nodeAlt = 0
    msg.nodeChildren = 0
    msg.nodeStatus = 0
    msg.nodeLabel = ""
    msg.nodeNoGood = ""
    msg.nodeInfo = ""
    msg.restartId = ""
end

function to_bytes(msg::Message)::Vector{UInt8}
    #create an output stream to write bytes to
    io = IOBuffer();

    #first byte = message type
    write(io, to_bytes(Int(msg.msgType), 1));

    if msg.msgType == NODE
        #required arguments according to the protocol (https://github.com/cp-profiler/cp-profiler)
        node_id =           to_bytes_big_endian(msg.nodeId, 4);
        node_restart_id =   to_bytes_big_endian(msg.restartId, 4);
        node_thread_id =    to_bytes_big_endian(-1, 4);
        node_parent_id =    to_bytes_big_endian(msg.nodePid, 4);
        parent_restart_id = to_bytes_big_endian(msg.restartId, 4);
        parent_thread_id =  to_bytes_big_endian(-1, 4);
        msg_alt =           to_bytes_big_endian(msg.nodeAlt, 4)
        msg_kid =           to_bytes_big_endian(msg.nodeChildren, 4);
        msg_status =        to_bytes_big_endian(msg.nodeStatus, 1);
        write(io, node_id);
        write(io, node_restart_id);
        write(io, node_thread_id);
        write(io, node_parent_id);
        write(io, parent_restart_id);
        write(io, parent_thread_id);
        write(io, msg_alt);
        write(io, msg_kid);
        write(io, msg_status);

        #optional argument: nodeLabel
        if (msg.nodeLabel != "")
            info = to_bytes(Int(LABEL), 1);
            data = Vector{UInt8}(msg.nodeLabel);
            size = to_bytes_big_endian(length(data), 4);
            write(io, info);
            write(io, size);
            write(io, data);
        end

        #optional argument: nodeNoGood
        if (msg.nodeNoGood != "")
            info = to_bytes(Int(NOGOOD), 1);
            data = Vector{UInt8}(msg.nodeNoGood);
            size = to_bytes_big_endian(length(data), 4);
            write(io, info);
            write(io, size);
            write(io, data);
        end

        #optional argument: nodeInfo
        if (msg.nodeInfo != "")
            info = to_bytes(Int(INFO), 1);
            data = Vector{UInt8}("{\"name\": \"$(msg.nodeInfo)\"}");
            size = to_bytes_big_endian(length(data), 4);
            write(io, info);
            write(io, size);
            write(io, data);
        end

    elseif msg.msgType == START
        #optional argument: name
        if (msg.modelName != "")
            info = to_bytes(Int(INFO), 1);
            data = Vector{UInt8}("{\"name\": \"$(msg.modelName)\"}");
            size = to_bytes_big_endian(length(data), 4);
            write(io, info);
            write(io, size); #the size of optional arguments should be in big endian ... ?
            write(io, data);
        end
    end

    #prepend the size of the message
    data = take!(io);
    size = to_bytes(length(data), 4); #the size of the message should be in little endian ... ?
    return vcat(size, data);
end

function to_bytes(a::Int)::Vector{UInt8}
    return to_bytes(a, sizeof(a)-leading_zeros(a)>>3)
end

function to_bytes(a::Int, byteSize::Int)::Vector{UInt8}
    return [(a>>((i-1)<<3)) % UInt8 for i in 1:byteSize]
end

function to_bytes_big_endian(a::Int, byteSize::Int)::Vector{UInt8}
    return reverse(to_bytes(a, byteSize))
end

