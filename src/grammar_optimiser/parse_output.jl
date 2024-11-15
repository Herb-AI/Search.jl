using JSON
"""
    read_json(json_content::String)

Reads a JSON file and returns the parsed content.
# Arguments
- `json_file::String`: the path to the JSON file
# Result
- `json_parsed::Dict`: the parsed JSON content
"""
function read_json(json_content)
    json_parsed = JSON.parse(json_content)
    witnesses = json_parsed["Call"][1]["Witnesses"]
    last_witness = witnesses[end]
    last_value = last_witness["Value"] #The best solution found
    return last_value
end