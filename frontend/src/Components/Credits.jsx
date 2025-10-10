import React from 'react';
import './Credits.css';
import { Link } from 'react-router-dom';
import exerly_logo from './Assets/ExerlyLogo.jpg';

const Credits = () => {
  return (
    <>
      <Link to="/" className="back-button">← Back</Link>

      <div className="credits-container">
        <img src={exerly_logo} alt="Exerly Logo" className="credits-logo" />
        <h1>Credits</h1>
        <div className="underline"></div>

        <p>Crafted with 💜 by Ali Younes</p>

        <div className="credits-links">
          <a
            href="https://www.linkedin.com/in/ali-younes-41a2b4296/"
            target="_blank"
            rel="noopener noreferrer"
          >
            LinkedIn
          </a>
          <a
            href="https://github.com/whoisaldo/Exerly-Fitness"
            target="_blank"
            rel="noopener noreferrer"
          >
            GitHub Repo
          </a>
          <Link to="/maintenance-history" className="maintenance-link">
            Maintenance History
          </Link>
          <Link to="/status-check" className="status-link">
            System Status
          </Link>
        </div>

        <p className="credits-description">
          Exerly is a passion project built to reshape the fitness experience with seamless UI, modern design, and scalable backend performance. More to come.
        </p>
      </div>
    </>
  );
};

export default Credits;
