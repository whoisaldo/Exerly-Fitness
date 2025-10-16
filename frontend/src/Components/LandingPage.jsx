import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import './LandingPage.css';
import exerly_logo from './Assets/ExerlyLogo.jpg';

export default function LandingPage() {
  const navigate = useNavigate();
  const [currentFeature, setCurrentFeature] = useState(0);
  const [stats, setStats] = useState({
    users: 0,
    activities: 0,
    meals: 0,
    hours: 0
  });

  const features = [
    {
      icon: '🎯',
      title: 'Smart Activity Tracking',
      description: 'Track workouts, runs, and daily activities with intelligent categorization and intensity monitoring.',
      image: '🏃‍♂️'
    },
    {
      icon: '🍎',
      title: 'Nutrition Management',
      description: 'Log meals with detailed macro tracking including protein, carbs, fat, and sugar monitoring.',
      image: '📊'
    },
    {
      icon: '😴',
      title: 'Sleep Analytics',
      description: 'Monitor sleep patterns with bedtime and wake time tracking for optimal recovery.',
      image: '🌙'
    },
    {
      icon: '📈',
      title: 'Progress Dashboard',
      description: 'Comprehensive analytics with goal tracking, progress charts, and personalized insights.',
      image: '📊'
    }
  ];

  const techStack = [
    { name: 'React.js', icon: '⚛️', description: 'Modern UI Framework' },
    { name: 'Node.js', icon: '🟢', description: 'Backend Runtime' },
    { name: 'MongoDB', icon: '🍃', description: 'NoSQL Database' },
    { name: 'Express.js', icon: '🚀', description: 'Web Framework' },
    { name: 'JWT Auth', icon: '🔐', description: 'Secure Authentication' },
    { name: 'RESTful API', icon: '🌐', description: 'Scalable Architecture' }
  ];

  const testimonials = [
    {
      text: "Exerly has transformed how I track my fitness journey. The interface is intuitive and the analytics are incredibly detailed.",
      author: "Sarah Chen",
      role: "Fitness Enthusiast"
    },
    {
      text: "The macro tracking feature is exactly what I needed for my nutrition goals. Clean, simple, and effective.",
      author: "Mike Rodriguez",
      role: "Health Coach"
    },
    {
      text: "As a developer, I'm impressed by the clean codebase and modern tech stack. Great work!",
      author: "Alex Thompson",
      role: "Full-Stack Developer"
    }
  ];

  // Animate stats on load
  useEffect(() => {
    const animateStats = () => {
      const targets = { users: 1247, activities: 15680, meals: 8934, hours: 2456 };
      const duration = 2000;
      const steps = 60;
      const stepDuration = duration / steps;
      
      let step = 0;
      const timer = setInterval(() => {
        step++;
        const progress = step / steps;
        const easeOut = 1 - Math.pow(1 - progress, 3);
        
        setStats({
          users: Math.floor(targets.users * easeOut),
          activities: Math.floor(targets.activities * easeOut),
          meals: Math.floor(targets.meals * easeOut),
          hours: Math.floor(targets.hours * easeOut)
        });
        
        if (step >= steps) {
          clearInterval(timer);
          setStats(targets);
        }
      }, stepDuration);
    };

    const timer = setTimeout(animateStats, 1000);
    return () => clearTimeout(timer);
  }, []);

  // Auto-rotate features
  useEffect(() => {
    const interval = setInterval(() => {
      setCurrentFeature((prev) => (prev + 1) % features.length);
    }, 4000);
    return () => clearInterval(interval);
  }, []);

  return (
    <div className="landing-page">
      {/* Navigation */}
      <nav className="landing-nav">
        <div className="nav-container">
          <div className="nav-logo">
            <img src={exerly_logo} alt="Exerly" className="logo-img" />
            <span className="logo-text">Exerly</span>
          </div>
          <div className="nav-links">
            <button className="nav-btn demo-btn" onClick={() => navigate('/')}>
              Try Demo
            </button>
            <button className="nav-btn login-btn" onClick={() => navigate('/')}>
              Sign In
            </button>
          </div>
        </div>
      </nav>

      {/* Hero Section */}
      <section className="hero-section">
        <div className="hero-container">
          <div className="hero-content">
            <div className="hero-badge">
              <span className="badge-icon">🚀</span>
              Modern Fitness Tracking Platform
            </div>
            <h1 className="hero-title">
              Transform Your <span className="gradient-text">Fitness Journey</span> with Smart Analytics
            </h1>
            <p className="hero-description">
              Track activities, monitor nutrition, analyze sleep patterns, and achieve your goals with 
              Exerly's comprehensive fitness management platform built with cutting-edge technology.
            </p>
            <div className="hero-actions">
              <button className="cta-primary" onClick={() => navigate('/')}>
                Start Free Trial
                <span className="cta-icon">→</span>
              </button>
              <button className="cta-secondary" onClick={() => navigate('/credits')}>
                View Project Details
              </button>
            </div>
          </div>
          <div className="hero-visual">
            <div className="dashboard-preview">
              <div className="preview-header">
                <div className="preview-dots">
                  <span></span>
                  <span></span>
                  <span></span>
                </div>
                <div className="preview-title">Exerly Dashboard</div>
              </div>
              <div className="preview-content">
                <div className="preview-stats">
                  <div className="stat-item">
                    <div className="stat-number">2,847</div>
                    <div className="stat-label">Calories Burned</div>
                  </div>
                  <div className="stat-item">
                    <div className="stat-number">8.5h</div>
                    <div className="stat-label">Sleep Quality</div>
                  </div>
                  <div className="stat-item">
                    <div className="stat-number">156g</div>
                    <div className="stat-label">Protein Intake</div>
                  </div>
                </div>
                <div className="preview-chart">
                  <div className="chart-bar" style={{height: '60%'}}></div>
                  <div className="chart-bar" style={{height: '80%'}}></div>
                  <div className="chart-bar" style={{height: '45%'}}></div>
                  <div className="chart-bar" style={{height: '90%'}}></div>
                  <div className="chart-bar" style={{height: '70%'}}></div>
                  <div className="chart-bar" style={{height: '85%'}}></div>
                  <div className="chart-bar" style={{height: '95%'}}></div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Stats Section */}
      <section className="stats-section">
        <div className="stats-container">
          <div className="stat-card">
            <div className="stat-number">{stats.users.toLocaleString()}</div>
            <div className="stat-label">Active Users</div>
          </div>
          <div className="stat-card">
            <div className="stat-number">{stats.activities.toLocaleString()}</div>
            <div className="stat-label">Activities Tracked</div>
          </div>
          <div className="stat-card">
            <div className="stat-number">{stats.meals.toLocaleString()}</div>
            <div className="stat-label">Meals Logged</div>
          </div>
          <div className="stat-card">
            <div className="stat-number">{stats.hours.toLocaleString()}</div>
            <div className="stat-label">Sleep Hours Monitored</div>
          </div>
        </div>
      </section>

      {/* Features Section */}
      <section className="features-section">
        <div className="features-container">
          <div className="section-header">
            <h2 className="section-title">Powerful Features for Modern Fitness</h2>
            <p className="section-description">
              Everything you need to track, analyze, and optimize your health and fitness journey.
            </p>
          </div>
          
          <div className="features-showcase">
            <div className="feature-content">
              <div className="feature-info">
                <div className="feature-icon">{features[currentFeature].icon}</div>
                <h3 className="feature-title">{features[currentFeature].title}</h3>
                <p className="feature-description">{features[currentFeature].description}</p>
                <div className="feature-indicators">
                  {features.map((_, index) => (
                    <button
                      key={index}
                      className={`indicator ${index === currentFeature ? 'active' : ''}`}
                      onClick={() => setCurrentFeature(index)}
                    />
                  ))}
                </div>
              </div>
            </div>
            <div className="feature-visual">
              <div className="feature-mockup">
                <div className="mockup-screen">
                  <div className="mockup-content">
                    <div className="mockup-header">
                      <div className="mockup-title">{features[currentFeature].title}</div>
                      <div className="mockup-icon">{features[currentFeature].image}</div>
                    </div>
                    <div className="mockup-data">
                      <div className="data-row">
                        <span className="data-label">Today's Progress</span>
                        <span className="data-value">85%</span>
                      </div>
                      <div className="data-row">
                        <span className="data-label">Weekly Goal</span>
                        <span className="data-value">6/7 days</span>
                      </div>
                      <div className="data-row">
                        <span className="data-label">Trend</span>
                        <span className="data-value trend-up">↗ +12%</span>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Tech Stack Section */}
      <section className="tech-section">
        <div className="tech-container">
          <div className="section-header">
            <h2 className="section-title">Built with Modern Technology</h2>
            <p className="section-description">
              Leveraging industry-standard tools and frameworks for scalability and performance.
            </p>
          </div>
          <div className="tech-grid">
            {techStack.map((tech, index) => (
              <div key={index} className="tech-card">
                <div className="tech-icon">{tech.icon}</div>
                <h4 className="tech-name">{tech.name}</h4>
                <p className="tech-description">{tech.description}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Testimonials Section */}
      <section className="testimonials-section">
        <div className="testimonials-container">
          <div className="section-header">
            <h2 className="section-title">What Users Say</h2>
            <p className="section-description">
              Real feedback from fitness enthusiasts and health professionals.
            </p>
          </div>
          <div className="testimonials-grid">
            {testimonials.map((testimonial, index) => (
              <div key={index} className="testimonial-card">
                <div className="testimonial-content">
                  <p className="testimonial-text">"{testimonial.text}"</p>
                  <div className="testimonial-author">
                    <div className="author-name">{testimonial.author}</div>
                    <div className="author-role">{testimonial.role}</div>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA Section */}
      <section className="cta-section">
        <div className="cta-container">
          <div className="cta-content">
            <h2 className="cta-title">Ready to Transform Your Fitness Journey?</h2>
            <p className="cta-description">
              Join thousands of users who are already achieving their health goals with Exerly.
            </p>
            <div className="cta-actions">
              <button className="cta-primary large" onClick={() => navigate('/')}>
                Get Started Free
                <span className="cta-icon">🚀</span>
              </button>
              <button className="cta-secondary large" onClick={() => navigate('/credits')}>
                Learn More
              </button>
            </div>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="landing-footer">
        <div className="footer-container">
          <div className="footer-content">
            <div className="footer-brand">
              <div className="footer-logo">
                <img src={exerly_logo} alt="Exerly" className="footer-logo-img" />
                <span className="footer-logo-text">Exerly</span>
              </div>
              <p className="footer-description">
                Modern fitness tracking platform built with React, Node.js, and MongoDB.
              </p>
            </div>
            <div className="footer-links">
              <div className="footer-column">
                <h4 className="footer-title">Product</h4>
                <a href="#features" className="footer-link">Features</a>
                <a href="#pricing" className="footer-link">Demo</a>
                <button onClick={() => navigate('/credits')} className="footer-link">About</button>
              </div>
              <div className="footer-column">
                <h4 className="footer-title">Resources</h4>
                <a href="https://github.com/whoisaldo/Exerly-Fitness" className="footer-link">GitHub</a>
                <a href="https://www.linkedin.com/in/ali-younes-41a2b4296/" className="footer-link">LinkedIn</a>
                <button onClick={() => navigate('/status-check')} className="footer-link">Status</button>
              </div>
            </div>
          </div>
          <div className="footer-bottom">
            <p className="footer-copyright">
              © 2025 Exerly. Built with ❤️ by Ali Younes.
            </p>
          </div>
        </div>
      </footer>
    </div>
  );
}
