import React, { useState } from 'react';
import './LoginSignup.css';
import user_icon     from '../Assets/person.png';
import email_icon    from '../Assets/email.png';
import password_icon from '../Assets/password.png';
import exerly_logo   from '../Assets/ExerlyLogo.jpg';
import { useNavigate, Link } from 'react-router-dom'; //
const BASE_URL = process.env.REACT_APP_API_URL;


const LoginSignup = () => {
  const [action,  setAction]  = useState('Sign Up');
  const [username, setUsername] = useState('');
  const [email,    setEmail]    = useState('');
  const [password, setPassword] = useState('');
  const navigate = useNavigate();

  const handleSignup = async () => {
    try {
      const res = await fetch(`${BASE_URL}/signup`, {
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
      const res = await fetch(`${BASE_URL}/login`, {
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
      <div className="header-section">
        <div className="logo-wrapper">
          <img src={exerly_logo} alt="Exerly Logo" className="exerly-logo" />
        </div>
        <div className="header">
          <h1 className="text">{action === 'Sign Up' ? 'Create Account' : 'Welcome Back'}</h1>
          <div className="underline"></div>
        </div>
      </div>

      <div className="subsection">
        <Link to="/credits" className="credits">Credits</Link>
        <div className="about">About</div>
        <div className="help">Help</div>
      </div>

      <form
        className="form-inputs"
        onSubmit={(e) => {
          e.preventDefault();
          if (action === 'Sign Up') handleSignup();
          else handleLogin();
        }}
      >
        {action !== 'Login' && (
          <div className="input">
            <img src={user_icon} alt="User Icon" />
            <input
              type="text"
              placeholder="Full Name"
              value={username}
              onChange={e => setUsername(e.target.value)}
              required
            />
          </div>
        )}

        <div className="input">
          <img src={email_icon} alt="Email Icon" />
          <input
            type="email"
            placeholder="Email"
            value={email}
            onChange={e => setEmail(e.target.value)}
            required
          />
        </div>

        <div className="input">
          <img src={password_icon} alt="Password Icon" />
          <input
            type="password"
            placeholder="Password"
            value={password}
            onChange={e => setPassword(e.target.value)}
            required
          />
        </div>

        {action === 'Login' && (
          <div className="forgot-password">
            Forgot Password? <span>Click Here!</span>
          </div>
        )}

        <div className="submit-container">
          <button
            type="submit"
            className={`submit ${action === 'Login' ? 'gray' : ''}`}
          >
            {action}
          </button>

          <button
            type="button"
            className={`submit toggle ${action === 'Login' ? '' : 'gray'}`}
            onClick={() => setAction(action === 'Login' ? 'Sign Up' : 'Login')}
          >
            {action === 'Login' ? 'Switch to Sign Up' : 'Switch to Login'}
          </button>
        </div>
      </form>
    </div>
  );
};

export default LoginSignup;
