import sys
import os
import json
import time

sys.path.insert(0, r"f:\BIGGER\.agents\worker_m3_1")
from studio_helper import StudioClient

def test_play_solo():
    client = StudioClient()
    print("Checking studio state...")
    state = client.get_studio_state()
    print("Initial state:", state)
    
    print("Starting Play Solo...")
    res = client.start_stop_play(True)
    print("Start play res:", res)
    time.sleep(5)
    
    # Query in Server Datamodel
    server_code = """
        local Players = game:GetService("Players")
        local player = Players:GetPlayers()[1]
        local playerName = player and player.Name or "NoPlayer"
        return "Server context loaded for player: " .. playerName
    """
    res = client.execute_luau(server_code, "Server")
    print("Server check:", res)
    
    # Query in Client Datamodel
    client_code = """
        local Players = game:GetService("Players")
        local player = Players.LocalPlayer
        local playerName = player and player.Name or "NoPlayer"
        return "Client context loaded for player: " .. playerName
    """
    res = client.execute_luau(client_code, "Client")
    print("Client check:", res)
    
    print("Stopping Play Solo...")
    client.start_stop_play(False)
    time.sleep(2)
    print("Stopped.")
    client.close()

if __name__ == "__main__":
    test_play_solo()
