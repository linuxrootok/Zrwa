import React, { useState, useEffect } from 'react';
import axios from 'axios';
import './App.css';

const API_BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:8080/api';

function App() {
  const [messages, setMessages] = useState([]);
  const [newMessage, setNewMessage] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  useEffect(() => {
    fetchMessages();
  }, []);

  const fetchMessages = async () => {
    try {
      setLoading(true);
      setError(null);
      const response = await axios.get(`${API_BASE_URL}/messages`);
      setMessages(response.data);
    } catch (err) {
      setError('Failed to fetch messages: ' + err.message);
      console.error('Error fetching messages:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!newMessage.trim()) return;

    try {
      setLoading(true);
      setError(null);
      const response = await axios.post(`${API_BASE_URL}/messages`, {
        content: newMessage
      });
      setMessages([...messages, response.data]);
      setNewMessage('');
    } catch (err) {
      setError('Failed to create message: ' + err.message);
      console.error('Error creating message:', err);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="App">
      <header className="App-header">
        <h1>Fullstack App</h1>
        <p>Java + MySQL + Redis + React</p>
      </header>

      <main className="App-main">
        <div className="message-form">
          <h2>Add Message</h2>
          <form onSubmit={handleSubmit}>
            <input
              type="text"
              value={newMessage}
              onChange={(e) => setNewMessage(e.target.value)}
              placeholder="Enter message..."
              disabled={loading}
            />
            <button type="submit" disabled={loading}>
              {loading ? 'Sending...' : 'Send'}
            </button>
          </form>
        </div>

        {error && <div className="error">{error}</div>}

        <div className="messages">
          <h2>Messages</h2>
          {loading && messages.length === 0 ? (
            <p>Loading...</p>
          ) : messages.length === 0 ? (
            <p>No messages yet.</p>
          ) : (
            <ul>
              {messages.map((message) => (
                <li key={message.id}>
                  <div className="message-content">{message.content}</div>
                  <div className="message-time">
                    {message.createdAt ? new Date(message.createdAt).toLocaleString() : ''}
                  </div>
                </li>
              ))}
            </ul>
          )}
        </div>
      </main>
    </div>
  );
}

export default App;

