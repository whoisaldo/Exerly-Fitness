// frontend/src/Components/LoginSignup/LoginSignup.jsx
import React, { useState } from 'react';
import './LoginSignup.css';
import user_icon     from '../Assets/person.png';
import email_icon    from '../Assets/email.png';
import password_icon from '../Assets/password.png';
import exerly_logo   from '../Assets/ExerlyLogo.jpg';
import { useNavigate, Link } from 'react-router-dom'; //



const LoginSignup = () => {
  const [action,  setAction]  = useState('Sign Up');
  const [username, setUsername] = useState('');
  const [email,    setEmail]    = useState('');
  const [password, setPassword] = useState('');
  const navigate = useNavigate();

  const handleSignup = async () => {
    try {
      const res = await fetch('https://powerful-citadel-83317-b198c7aed44f.herokuapp.com/signup', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name: username, email, password })
      });
      const data = await res.json();
      alert(data.message);
      if (res.ok) setAction('Login');
    } catch (err) {
      alert('Signup failed');
      console.error(err);
    }
  };

  const handleLogin = async () => {
    try {
      const res = await fetch('https://powerful-citadel-83317-b198c7aed44f.herokuapp.com/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password })
      });
      const data = await res.json();
      if (data.token) {
        localStorage.setItem('token', data.token);
        alert('Login successful!');
        navigate('/dashboard');
      } else {
        alert(data.message);
      }
    } catch (err) {
      alert('Login failed');
      console.error(err);
    }
  };

  return (
    <div className="container">
      <div className="logo-wrapper">
        <img src={exerly_logo} alt="Logo" className="exerly-logo" />
      </div>

      <div className="header">
        <div className="text">{action}</div>
        <div className="underline"></div>
      </div>

      <div className="subsection">
        <div className="help">Help</div>
        <div className="about">About</div>
        <Link to="/credits" className="credits">Credits</Link>
      </div>

      <div className="inputs">
        {action === 'Login' ? null : (
          <div className="input">
            <img src={user_icon} alt="" />
            <input
              type="text"
              placeholder="Name"
              value={username}
              onChange={e => setUsername(e.target.value)}
            />
          </div>
        )}

        <div className="input">
          <img src={email_icon} alt="" />
          <input
            type="email"
            placeholder="Email"
            value={email}
            onChange={e => setEmail(e.target.value)}
          />
        </div>

        <div className="input">
          <img src={password_icon} alt="" />
          <input
            type="password"
            placeholder="Password"
            value={password}
            onChange={e => setPassword(e.target.value)}
          />
        </div>
      </div>

      {action === 'Login' && (
        <div className="forgot-password">
          Forgot Password? <span>Click Here!</span>
        </div>
      )}

      <div className="submit-container">
        <div
          className="submit"
          onClick={() => {
            if (action === 'Sign Up') handleSignup();
            else setAction('Sign Up');
          }}
        >
          Sign Up
        </div>

        <div
          className="submit gray"
          onClick={() => {
            if (action === 'Login') handleLogin();
            else setAction('Login');
          }}
        >
          Login
        </div>
      </div>
    </div>
  );
};

export default LoginSignup;
