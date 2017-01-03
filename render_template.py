import sys
import json
import copy

import pystache

num_args = 3

agent_needed_keys = ["is_is_hostname", "is_is_logfile", "is_is_router_address", "num_areas", "num_nodes"]

def main():
    args = sys.argv[1:]
    print("args received: " + str(args))
    if len(args) != num_args:
        print("ERROR, wrong number of arguments ({}) supplied instead of {}".format(len(args), num_args))
        exit(1)

    template_file = args[0]
    render_target_file = args[1]
    data_str = args[2]
    
    print("")
    print("Rendering template {} to {} with data {}".format(template_file, render_target_file, data_str))
    print("")
    print("Loading data as json...")
    try:
        data = json.loads(data_str)
    except Exception as e:
        print("ERROR, exception loading json data: {}".format(e))
        exit(1)

    print("Validating needed keys are present.")
    if not all (k in data for k in agent_needed_keys):
        print("ERROR, not all of the following keys found in data: {}".format(agent_needed_keys))
        exit(1)

    print("Generating template data...")
    template_data = copy.copy(data)
    num_areas = template_data.pop("num_areas")
    num_nodes = template_data.pop("num_nodes")
   
    template_data["areas"] = []
    template_data["nodes"] = []

    for i in xrange(1,num_areas+1):
        template_data["areas"].append("{:03d}".format(i))

    for i in xrange(1,num_areas+1):
        template_data["nodes"].append({"eth": "{}".format(i),
                                       "is_is_instance": "{:03d}".format(i)})

    print("template_data = {}".format(template_data))

    
    rendered_template = ""
    
    print("Opening file {}".format(template_file))
    with open(template_file, 'r') as temp_f:
        print("Rendering template ...")
        rendered_template += pystache.render(temp_f.read(), template_data)

    print("Opening file {}".format(render_target_file))
    with open(render_target_file, "w") as render_f:
        print("Writing rendered template ...")
        render_f.write(rendered_template)

if __name__ == "__main__":
    print("Starting render_template.py ...\n")
    main()
    print("\nExiting render_template.py ...")

