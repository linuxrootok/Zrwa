import React, { useState, useEffect } from 'react';
import axios from 'axios';
import './App.css';

// 在生产环境中使用相对路径（通过 Nginx 代理），开发环境使用完整 URL
// 注意：在构建时，React 会将 process.env.NODE_ENV 替换为 'production'
const getApiBaseUrl = () => {
  if (process.env.REACT_APP_API_URL) {
    return process.env.REACT_APP_API_URL;
  }
  // 生产环境使用相对路径，开发环境使用完整 URL
  return process.env.NODE_ENV === 'production' ? '/api' : 'http://localhost:8080/api';
};

const API_BASE_URL = getApiBaseUrl();

// 配置 axios 默认设置
axios.defaults.timeout = 10000; // 10 秒超时
axios.defaults.headers.common['Content-Type'] = 'application/json';

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
      console.log('Sending POST request to:', `${API_BASE_URL}/messages`);
      const response = await axios.post(`${API_BASE_URL}/messages`, {
        content: newMessage
      });
      console.log('Response received:', response.data);
      setMessages([...messages, response.data]);
      setNewMessage('');
    } catch (err) {
      const errorMessage = err.response 
        ? `Server error: ${err.response.status} - ${err.response.statusText}`
        : err.message || 'Network error';
      setError('Failed to create message: ' + errorMessage);
      console.error('Error creating message:', err);
      console.error('Error details:', {
        message: err.message,
        response: err.response,
        request: err.request,
        config: err.config
      });
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


