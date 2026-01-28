import os,sys,json,subprocess

def setup():
    from meld_graph.paths import MELD_DATA_PATH
    
    # Check if FREESURFER_HOME is already set (e.g., from container wrapper)
    if "FREESURFER_HOME" in os.environ:
        print(f"Using FreeSurfer from: {os.environ['FREESURFER_HOME']}")
    else:
        # Should only be run on mac for native installation
        if sys.platform == "darwin":
            if os.path.exists("/Applications/freesurfer/7.2.0"):
                os.environ["FREESURFER_HOME"] = "/Applications/freesurfer/7.2.0"
        
        # Only try to source FreeSurfer if freeview is not found
        freesurfercheck = subprocess.run(['/bin/bash', '-c', "type freeview"], capture_output=True)
        if freesurfercheck.returncode > 0:
            # Try to find and source FreeSurfer
            possible_paths = [
                '/Applications/freesurfer/7.2.0/SetUpFreeSurfer.sh',
                '/usr/local/freesurfer/SetUpFreeSurfer.sh',
            ]
            
            source = None
            for path in possible_paths:
                if os.path.exists(path):
                    source = f'source {path}'
                    break
            
            if source:
                # Grab all of the environment variables 
                dump = 'python -c "import os,json;print(json.dumps(dict(os.environ)))"'
                # Source freesurfer then grab all of the environment variables and store in penv
                penv = subprocess.run(["/bin/bash", "-c", f"{source} && {dump}"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                if penv.returncode == 0 and penv.stdout:
                    try:
                        # Load the environment variables in this process
                        env = json.loads(penv.stdout)
                        os.environ.update(env)
                    except json.JSONDecodeError:
                        print("Warning: Could not parse FreeSurfer environment variables")
                        print("Continuing with existing environment...")
            else:
                print("Warning: FreeSurfer setup script not found")
                print("Assuming FreeSurfer is available via PATH or container wrapper")
    
    # Set up license
    if not "FS_LICENSE" in os.environ:
        if os.path.exists(f"{MELD_DATA_PATH}/license.txt"):
            print("setting license" + f"{MELD_DATA_PATH}/license.txt")
            os.environ["FS_LICENSE"] = f"{MELD_DATA_PATH}/license.txt"
        elif os.path.exists(f"{os.getcwd()}/license.txt"):
            print("setting license" + f"{os.getcwd()}/license.txt")
            os.environ["FS_LICENSE"] = f"{os.getcwd()}/license.txt"
        else:
            print("Couldn't find Freesurfer license file. Please copy license.txt to the meld folder or set FS_LICENSE manually")
            sys.exit(-1)
