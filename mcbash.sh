#!/bin/bash

# Variables
DEFAULT_SERVER_PROPERTIES="server_properties_template.txt"  # Preconfigured server.properties template
SERVER_DIR=$(pwd)  # Replace with your server path
JAVA_ARGS="-Xms4G -Xmx6G -jar"
BACKUP_DIR="$SERVER_DIR/backups"

# Function for setting up a new server
setup_new_server() {
    echo "Setting up a new Fabric Minecraft server."

    # Prompt for Minecraft version, Fabric loader version, and folder name
    read -rp "Enter Minecraft version (e.g., 1.21.4): " mc_version
    read -rp "Enter Fabric loader version (e.g., 0.16.9): " fabric_version
    installer_version="1.0.1"  # Default installer version
    read -rp "Enter folder name for the new server: " folder_name

    # Create the server directory
    mkdir -p "$folder_name"
    cd "$folder_name" || exit

    # Download Fabric server jar
    echo "Downloading Fabric server..."
    curl -OJ "https://meta.fabricmc.net/v2/versions/loader/$mc_version/$fabric_version/$installer_version/server/jar"

    # Find the downloaded file name
    downloaded_file=$(ls | grep -i "fabric-server.*\.jar")
    if [ -z "$downloaded_file" ]; then
        echo "Error: Minecraft server JAR file was not downloaded."
        exit 1
    fi

    mv "$downloaded_file" "fabric-server.jar"
    echo "Renamed server jar to fabric-server.jar."

    # Create EULA file
    echo "eula=true" > eula.txt

    # Check if server_properties_template.txt exists
    if [ -f "$HOME/server_properties_template.txt" ]; then
        cp "$HOME/server_properties_template.txt" server.properties
    else
        cat <<EOF > server.properties
# Minecraft server properties
allow-nether=true
level-name=world
enable-query=false
allow-flight=true
server-port=25565
max-build-height=256
spawn-npcs=true
difficulty=hard
EOF
    fi

    # Create VARIABLES.TXT
    cat <<EOF > VARIABLES.TXT
SERVER_DIR=$(pwd)
JAR_FILE=fabric-server.jar
MEM_MIN=4G
MEM_MAX=6G
JAVA_ARGS="-Xms\$MEM_MIN -Xmx\$MEM_MAX -jar"
BACKUP_DIR="\$SERVER_DIR/backups"
tmux_session_name=$folder_name
EOF

    # Create start.sh script
    cat <<EOF > start.sh
#!/bin/bash
source VARIABLES.TXT
#  Start server in
tmux new-session -d -s "\$tmux_session_name" "java \$JAVA_ARGS \$SERVER_DIR/\$JAR_FILE nogui"
if [ $? -eq 0 ]; then
    echo "Server started in tmux session: $folder_name."
    echo "Errors and output are being logged to server_error.log."
    echo "To attach to the server session, use: tmux attach-session -t $folder_name"
else
    echo "Failed to start server. Check tmux and server_error.log for errors."
fi
EOF
    chmod +x start.sh
    echo "Fabric server setup complete in folder: $folder_name"
}

# Function to start the server
start_server() {
    read -rp "Enter the server directory name: " folder_name
    cd "$folder_name" || exit
    tmux_session_name=$(basename "$folder_name")
    tmux new-session -d -s "$tmux_session_name" "java $JAVA_ARGS fabric-server.jar nogui"
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
echo "1. Start Server"
echo "2. Stop Server"
echo "3. Backup World"
echo "4. Server Status"
echo "5. Set Up New Fabric Server"
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
