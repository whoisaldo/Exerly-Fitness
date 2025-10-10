import React from 'react';
import './Credits.css';
import { Link } from 'react-router-dom';
import exerly_logo from './Assets/ExerlyLogo.jpg';

const Credits = () => {
  return (
    <div className="credits-page">
      <Link to="/" className="back-button">← Back</Link>

      <div className="credits-container">
        <div className="credits-header">
          <img src={exerly_logo} alt="Exerly Logo" className="credits-logo" />
          <h1>About Exerly</h1>
          <p className="credits-tagline">Redefining fitness tracking with modern technology</p>
        </div>

        <div className="credits-content">
          <div className="creator-section">
            <h2>Crafted with 💜 by</h2>
            <div className="creator-info">
              <div className="creator-name">Ali Younes</div>
              <div className="creator-title">Full-Stack Developer & Fitness Enthusiast</div>
            </div>
          </div>

          <div className="features-section">
            <h3>What makes Exerly special?</h3>
            <div className="features-grid">
              <div className="feature-card">
                <div className="feature-icon">🎯</div>
                <h4>Smart Tracking</h4>
                <p>Intelligent activity and nutrition tracking with personalized insights</p>
              </div>
              <div className="feature-card">
                <div className="feature-icon">📊</div>
                <h4>Analytics Dashboard</h4>
                <p>Comprehensive data visualization and progress monitoring</p>
              </div>
              <div className="feature-card">
                <div className="feature-icon">⚡</div>
                <h4>Modern Tech</h4>
                <p>Built with React, Node.js, and MongoDB for optimal performance</p>
              </div>
              <div className="feature-card">
                <div className="feature-icon">🔒</div>
                <h4>Secure & Private</h4>
                <p>Your data is protected with enterprise-grade security</p>
              </div>
            </div>
          </div>

          <div className="links-section">
            <h3>Connect & Explore</h3>
            <div className="credits-links">
              <a
                href="https://www.linkedin.com/in/ali-younes-41a2b4296/"
                target="_blank"
                rel="noopener noreferrer"
                className="social-link linkedin"
              >
                <span className="link-icon">💼</span>
                LinkedIn
              </a>
              <a
                href="https://github.com/whoisaldo/Exerly-Fitness"
                target="_blank"
                rel="noopener noreferrer"
                className="social-link github"
              >
                <span className="link-icon">🔗</span>
                GitHub Repo
              </a>
              <Link to="/status-check" className="social-link status">
                <span className="link-icon">📊</span>
                System Status
              </Link>
            </div>
          </div>

          <div className="footer-section">
            <p className="credits-description">
              Exerly is a passion project built to reshape the fitness experience with seamless UI, 
              modern design, and scalable backend performance. More exciting features coming soon!
            </p>
            <div className="version-info">
              <span>Version 1.0.0</span>
              <span>•</span>
              <span>Built with ❤️ in 2025</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Credits;
