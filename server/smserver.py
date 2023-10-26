


''' ECHO MESSAGES BACK TO SENDING CLIENT ONLY
async def server(ws, path):
    async for msg in ws:
        # msg = msg.decode("utf-8")
        print(f"CLIENT: {msg}")
        await ws.send(f"RECEIVED: {msg}")

start_sever = websockets.serve(server, HOST, PORT)
print("Server started")
asyncio.get_event_loop().run_until_complete(start_sever)
asyncio.get_event_loop().run_forever()
'''


'''
We use an authenticated flag to determine if a client is authenticated. If the client is authenticated, their messages are broadcasted to the same lobby. If not, they must provide their LOBBY_CODE and CLIENT_NAME for authentication.

When a client sends a message with LOBBY_CODE and CLIENT_NAME, we check if the lobby exists. If the lobby exists, we check if the client name is already registered in the lobby. If not, we add the client to the lobby and set the authenticated flag to True.

After authentication, if a client sends a message with a 'message' key, it's treated as a chat message and broadcast to all clients in the same lobby.

If a client disconnects, they are removed from their respective lobby.

This code allows clients to authenticate with a lobby code and a client name and then communicate with other authenticated clients within the same lobby. Unauthenticated clients will not be able to send messages.
'''
import asyncio
import websockets
import json

HOST = 'localhost'
PORT = 5000

# Set up a dictionary to store lobbies and their clients
lobbies = {}

# Define a callback function that handles incoming messages
async def handle_client_connection(websocket, path):
    try:
        authenticated = False
        lobby_code = None
        client_name = None


        while True:
            message = await websocket.recv()
            if message:
                try:
                    data = json.loads(message)

                    if authenticated:
                        if 'message' in data:
                            if lobby_code in lobbies:
                                for client in lobbies[lobby_code]['clients']:
                                    if client != websocket:
                                        await client.send(f"{client_name}: {data['message']}")
                            else:
                                await websocket.send("Invalid lobby code. You may have been removed from the lobby.")
                                authenticated = False
                        elif 'INSTRUCTION' in data:
                            if lobby_code in lobbies:
                                action_data = data['INSTRUCTION'].split(':')
                                action = action_data[1]  # index 0 is the NOTE: prefix
                                object_id = str(action_data[2])

                                if action == 'CREATE':
                                    # Add a new object to the objects dictionary
                                    lobbies[lobby_code]['objects'][object_id] = {
                                        'position_x': action_data[3],
                                        'position_y': action_data[4]
                                    }

                                if object_id not in lobbies[lobby_code]['history']:
                                    lobbies[lobby_code]['history'][object_id] = {
                                        'CHANGE_TEXT': None,  # Store the latest CHANGE_TEXT instruction
                                        'MOVE': None  # Store the latest MOVE instruction
                                    }

                                if action in ('CHANGE_TEXT', 'MOVE'):
                                    event_data = {
                                        'action': action,
                                        **({'new_name': action_data[3]} if action == 'CHANGE_TEXT' else {}),
                                        **({'position_x': action_data[3], 'position_y': action_data[4]} if action == 'MOVE' else {})
                                    }

                                    # Update the latest instruction for the specific action type
                                    lobbies[lobby_code]['history'][object_id][action] = event_data

                                if action == 'DELETE':
                                    # Remove the object from the objects dictionary
                                    if object_id in lobbies[lobby_code]['objects']:
                                        del lobbies[lobby_code]['objects'][object_id]

                                # Forward the instruction to all connected clients
                                for client in lobbies[lobby_code]['clients']:
                                    if client != websocket:
                                        await client.send(f"{data['INSTRUCTION']}")

                                        

                            else:
                                await websocket.send("Invalid lobby code. You may have been removed from the lobby.")
                                authenticated = False
                        elif 'GET_LOBBY_HISTORY' in data:
                            if lobby_code in lobbies:
                                for client in lobbies[lobby_code]['clients']:
                                    if client == websocket:
                                        print(lobbies[lobby_code]['objects'])
                                        print(lobbies[lobby_code]['history'])

                                        # Repack the instructions and send them to all joining clients
                                        instructions = []

                                        if lobby_code in lobbies:
                                            objects = lobbies[lobby_code]['objects']
                                            history = lobbies[lobby_code]['history']

                                            for object_id, object_data in objects.items():
                                                create_instruction = f"NOTE:CREATE:{object_id}:{object_data['position_x']}:{object_data['position_y']}"
                                                instructions.append(create_instruction)

                                            for object_id, event_data in history.items():
                                                # Retrieve the latest "CHANGE_TEXT" and "MOVE" instructions
                                                change_text_instruction = event_data['CHANGE_TEXT']
                                                move_instruction = event_data['MOVE']

                                                # Append the latest "CHANGE_TEXT" instruction if available
                                                if change_text_instruction:
                                                    instructions.append(f"NOTE:CHANGE_TEXT:{object_id}:{change_text_instruction['new_name']}")

                                                # Append the latest "MOVE" instruction if available
                                                if move_instruction:
                                                    instructions.append(f"NOTE:MOVE:{object_id}:{move_instruction['position_x']}:{move_instruction['position_y']}")

                                        for instruction in instructions:
                                            await websocket.send(f"{instruction}")

                            else:
                                await websocket.send("Invalid lobby code. You may have been removed from the lobby.")
                                authenticated = False
                        elif 'LEAVE_LOBBY' in data:
                            if lobby_code in lobbies:
                                lobbies[lobby_code]['clients'].remove(websocket)
                                if not lobbies[lobby_code]['clients']:
                                    del lobbies[lobby_code]
                                await websocket.send("You have left the lobby.")
                                await websocket.send("STATUS:LOBBY_LEAVE_OK")
                            else:
                                await websocket.send("You are not in a lobby.")
                            authenticated = False  # Mark the client as not authenticated after leaving the lobby
                        else:
                            await websocket.send("Invalid message format.")
                    elif 'CREATE_LOBBY' in data and 'LOBBY_CODE' in data:
                        lobby_code = data['LOBBY_CODE']
                        client_name = data['CLIENT_NAME']

                        if lobby_code not in lobbies:
                            lobbies[lobby_code] = {} # {websocket}
                            lobbies[lobby_code]['clients'] = {websocket}
                            lobbies[lobby_code]['history'] = {}
                            lobbies[lobby_code]['objects'] = {}
                            authenticated = True
                            lobbies[lobby_code]['clients'].add(websocket)
                            await websocket.send(f"Welcome, {client_name}! You have created lobby {lobby_code}")
                            await websocket.send("STATUS:LOBBY_CREATED_OK")

                            

                        else:
                            await websocket.send("Lobby code already in use. Try another.")
                    elif 'LOBBY_CODE' in data and 'CLIENT_NAME' in data:
                        lobby_code = data['LOBBY_CODE']
                        client_name = data['CLIENT_NAME']

                        if lobby_code in lobbies:
                            if client_name in lobbies[lobby_code]['clients']:
                                await websocket.send("Client name already registered in this lobby.")
                            else:
                                lobbies[lobby_code]['clients'].add(websocket)
                                authenticated = True
                                await websocket.send(f"Welcome, {client_name}! You are now in lobby {lobby_code}")
                                await websocket.send("STATUS:LOBBY_JOINED_OK")
                        else:
                            await websocket.send("Invalid lobby code. Lobby doesn't exist.")
                    elif 'message' in data:
                        await websocket.send("Not connected to a lobby")
                    else:
                        await websocket.send("Invalid message format.")
                except json.JSONDecodeError:
                    await websocket.send("Invalid JSON format.")
            else:
                break
    except websockets.exceptions.ConnectionClosedError:
        pass
    finally:
        # Remove the client from the lobby when they disconnect
        if authenticated and lobby_code in lobbies:
            lobbies[lobby_code]['clients'].remove(websocket)
            # If the lobby is empty, remove it
            if not lobbies[lobby_code]['clients']:
                del lobbies[lobby_code]
                print(f"Lobby {lobby_code} deleted")

if __name__ == "__main__":
    # Start the WebSocket server
    server = websockets.serve(handle_client_connection, HOST, PORT)
    print("Server started")
    asyncio.get_event_loop().run_until_complete(server)
    asyncio.get_event_loop().run_forever()
