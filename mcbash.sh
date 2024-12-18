#!/bin/bash

# Variables
DEFAULT_SERVER_PROPERTIES="server_properties_template.txt"  # Preconfigured server.properties template
SERVER_DIR=$(pwd)  # Replace with your server path
JAVA_ARGS="-Xms4G -Xmx6G -jar"
BACKUP_DIR="$SERVER_DIR/backups"

# Function for setting up a new server
setup_new_server() {
    echo "Setting up a new Minecraft server."

    # Prompt for server type
    echo "Select server type:"
    echo "1. Fabric"
    echo "2. Forge"
    echo "3. Vanilla"
    read -rp "Enter the number for the desired server type: " server_type

    case $server_type in
    1)
        server_type="Fabric"
        ;;
    2)
        server_type="Forge"
        ;;
    3) 
        server_type="Vanilla"
        ;;
    *)
        echo "Invalid option. Please select 1 for Fabric, 2 for Forge, or 3 for Vanilla."
        return
        ;;
    esac

    # Prompt for Minecraft version and folder name
    read -rp "Enter Minecraft version (e.g., 1.21.4): " mc_version
    read -rp "Enter folder name for the new server: " folder_name

    # Create the server directory
    mkdir -p "$folder_name"
    cd "$folder_name" || exit

    # Handle server-specific setup
    if [ "$server_type" == "Fabric" ]; then
        read -rp "Enter Fabric loader version (e.g., 0.16.9): " fabric_version
        installer_version="1.0.1"  # Default installer version for Fabric

        echo "Downloading Fabric server..."
        curl -OJ "https://meta.fabricmc.net/v2/versions/loader/$mc_version/$fabric_version/$installer_version/server/jar"

        # Find and verify the downloaded file
        downloaded_file=$(ls | grep -i "fabric-server.*\.jar")
        if [ -z "$downloaded_file" ]; then
            echo "Error: Fabric server JAR file was not downloaded."
            exit 1
        fi
        # Set JAR_FILE dynamically based on the downloaded file
        JAR_FILE="$downloaded_file"

    elif [ "$server_type" == "Forge" ]; then
        read -rp "Enter Forge installer version (e.g., 54.0.0): " forge_version

        echo "Downloading Forge installer..."
        curl -OJ "https://maven.minecraftforge.net/net/minecraftforge/forge/$mc_version-$forge_version/forge-$mc_version-$forge_version-installer.jar"
                  https://maven.minecraftforge.net/net/minecraftforge/forge/$mc_version-$forge_version/forge-$mc_version-$forge_version-installer.jar
        # Find and verify the downloaded file
        downloaded_file=$(ls | grep -i "forge-.*-installer\.jar")
        if [ -z "$downloaded_file" ]; then
            echo "Error: Forge installer JAR file was not downloaded."
            exit 1
        fi

        # Run the Forge installer
        echo "Running Forge installer..."
        java -jar "$downloaded_file" --installServer
        echo "Forge server setup complete."
        # Find the downloaded Forge server jar file
        JAR_FILE=$downloaded_file


    elif [ "$server_type" == "Vanilla" ]; then
        echo "Downloading Vanilla server jar..."
        wget https://mcutils.com/api/server-jars/vanilla/"$mc_version"/download -O vanilla-"$mc_version".jar
        JAR_FILE=$(ls | grep -i "vanilla-.*\.jar")
        echo "Set JAR_FILE to $JAR_FILE."
        # Verify the download
        if [ ! -f "vanilla-$mc_version.jar" ]; then
            echo "Error: Vanilla server JAR file was not downloaded."
            exit 1
        fi

        echo "Vanilla server setup complete."
    else
        echo "Unexpected error occurred during server setup."
        exit 1
    fi
    # Create EULA file
    echo "Creating EULA file..."
    echo "eula=true" > "eula.txt"

    # Check if server_properties_template.txt exists and copy it to server.properties
    if [ -f "$SERVER_DIR/server_properties_template.txt" ]; then
        echo "Generating server.properties from template..."
        cp "$SERVER_DIR/server_properties_template.txt" "server.properties"
    else
        echo "server_properties_template.txt not found. Creating default server.properties..."
        cat <<EOF > "server.properties"
# Minecraft server properties
# Generated by script

allow-nether=true
level-name=world
enable-query=false
allow-flight=true
server-port=25565
max-build-height=256
spawn-npcs=true
difficulty=hard
gamemode=0
enable-command-block=false
max-players=20
spawn-monsters=true
view-distance=10
server-ip=
spawn-animals=true
white-list=false
generate-structures=true
online-mode=true
resource-pack=
spawn-protection=0
max-world-size=29999984
motd=A Minecraft Server
EOF
    fi
# Create VARIABLES.TXT
    cat <<EOF > variables.txt
SERVER_DIR=$(pwd)
JAR_FILE=$JAR_FILE
MEM_MIN=4G
MEM_MAX=6G
JAVA_ARGS="-Xms\$MEM_MIN -Xmx\$MEM_MAX -jar"
BACKUP_DIR="\$SERVER_DIR/backups"
tmux_session_name=$folder_name
EOF

    # Create start.sh script
    cat <<EOF > "start.sh"
#!/bin/bash
source variables.txt

# Start the server in tmux, but also log the output to a file.
tmux new-session -d -s "$tmux_session_name" \
  "java $JAVA_ARGS $SERVER_DIR/$JAR_FILE nogui 2>&1 | tee -a server_error.log"

if [ $? -eq 0 ]; then
    echo "Server started in tmux session: $tmux_session_name."
    echo "Errors and output are being logged to server_error.log."
    echo "To attach to the server session, use: tmux attach-session -t $tmux_session_name"
else
    echo "Failed to start server. Check tmux and server_error.log for errors."
fi

}

# Function to stop the server
stop_server() {
    echo "Stopping Minecraft server..."
    read -rp "Enter the tmux session name to stop: " tmux_session_name
    if tmux has-session -t "$tmux_session_name" 2>/dev/null; then
        tmux send-keys -t "$tmux_session_name" "stop" C-m
        sleep 5
        tmux kill-session -t "$tmux_session_name"
    else
        echo "No such tmux session found."
    fi
}

# Function to backup a world
backup_world() {
    read -rp "Enter the tmux session name to backup: " tmux_session_name
    if tmux has-session -t "$tmux_session_name" 2>/dev/null; then
        mkdir -p "$BACKUP_DIR"
        TIMESTAMP=$(date +'%Y%m%d%H%M%S')
        tar -czvf "$BACKUP_DIR/world_backup_$TIMESTAMP.tar.gz" "$SERVER_DIR/$tmux_session_name/world"
    else
        echo "No such tmux session found."
    fi
}

# Function to check server status
server_status() {
    tmux_sessions=$(tmux list-sessions | grep -oP '^\S+')
    if [ -z "$tmux_sessions" ]; then
        echo "No Minecraft servers are running."
    else
        for session in $tmux_sessions; do
            PID=$(pgrep -f "$session")
            echo "Session: $session, PID: $PID"
        done
    fi
}

# Menu
echo "Minecraft Server Manager"
echo "1. Start Server [WIP]"
echo "2. Stop Server"
echo "3. Backup World"
echo "4. Server Status"
echo "5. Set Up New Server"
echo "6. Exit"
read -rp "Select an option: " OPTION

case $OPTION in
1) start_server ;;
2) stop_server ;;
3) backup_world ;;
4) server_status ;;
5) setup_new_server ;;
6) echo "Exiting..." ;;
*) echo "Invalid option. Please select a valid number." ;;
esac
