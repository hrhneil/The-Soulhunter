using System;
using System.Net.Sockets;
using MongoDB.Bson;

public class Player {
    private BsonDocument data;
    private NetworkStream upstream;

    private string login;

    private Character character;

    public Player(NetworkStream stream) {
        upstream = stream;
    }

    public void LogIn(BsonDocument _data) {
        data = _data;

        login = data.GetValue("login").AsString;

        character = null;
    }

    public void LogOut() {
        Server.RemoveOnlinePlayer(this);

        if (character != null) {
            character.RemoveFromRoom();
        }
    }

    public string GetLogin() {return login;}

    public void SetCharacter(string name) {
        character = new Character(this, data);
    }

    public Character GetCharacter() {return character;}

    public void SendPacket(Packet packet) {
        packet.Send(upstream);
    }
}