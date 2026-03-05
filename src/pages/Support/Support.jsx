import { useEffect, useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import axios from 'axios';
import { toast } from 'react-hot-toast';
import useHaptic from '../../hooks/useHaptic';
import '../Home/Home.css';
import './Support.css';

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || '';
const isMockMode = !API_BASE_URL;

/* -----------------------------
   Ticket Status Mapping
----------------------------- */

const getStatusTag = (status) => {

  const map = {
    NEW: { label: "New", class: "status-new" },
    IN_PROGRESS: { label: "In Progress", class: "status-progress" },
    WAITING_FOR_CUSTOMER: { label: "Waiting For You", class: "status-waiting" },
    WAITING_FOR_INTERNAL_TEAM: { label: "Internal Review", class: "status-review" },
    RESOLVED: { label: "Resolved", class: "status-resolved" },
    CLOSED: { label: "Closed", class: "status-closed" }
  };

  return map[status] || { label: status, class: "status-default" };

};

const Support = () => {

  const navigate = useNavigate();
  const { lightTap, mediumTap } = useHaptic();

  const [tickets, setTickets] = useState([]);
  const [loading, setLoading] = useState(true);

  /* -----------------------------
     Fetch Support Tickets
  ----------------------------- */

  useEffect(() => {

    const fetchTickets = async () => {

      try {

        if (isMockMode) {

          const userTickets =
            JSON.parse(localStorage.getItem('supportTickets') || '[]');

          setTickets(userTickets);

        } else {

          const storedUser =
            JSON.parse(localStorage.getItem('quickplate_user') || '{}');

          const res = await axios.get(
            `${API_BASE_URL}/services/apexrest/case/list?customerId=${storedUser.customerId}`
          );

          setTickets(res.data || []);

        }

      } catch (err) {

        console.error("Ticket fetch error:", err);

      } finally {

        setLoading(false);

      }

    };

    fetchTickets();

  }, []);

  /* -----------------------------
     Notifications
  ----------------------------- */

  const handleNotificationClick = () => {

    lightTap();

    if (tickets.length > 0) {

      toast.success(`You have ${tickets.length} active tickets`, {
        icon: '🔔',
        style: {
          borderRadius: '12px',
          background: '#1A1D1F',
          color: '#fff',
        }
      });

    } else {

      toast('No new notifications', { icon: '🔕' });

    }

  };

  return (

    <div className="support-container">

      {/* Header */}

      <header className="support-header">

        <button
          className="support-back-btn"
          onClick={() => { lightTap(); navigate(-1); }}
        >
          <span className="material-symbols-outlined">arrow_back_ios_new</span>
        </button>

        <h1 className="support-title">Support Center</h1>

        <div className="support-badge-container">

          <button
            className="support-icon-btn"
            onClick={handleNotificationClick}
          >
            <span className="material-symbols-outlined">notifications</span>
            {tickets.length > 0 && <span className="support-badge"></span>}
          </button>

        </div>

      </header>

      {/* Main */}

      <main className="support-main">

        {/* Hero */}

        <div className="support-hero">
          <h2>How can we help?</h2>
          <p>Track your support tickets or raise a new issue</p>
        </div>

        {/* Quick Actions */}

        <section className="support-section">

          <div className="support-section-header">
            <h3 className="support-section-title">Quick Actions</h3>
          </div>

          <div className="support-actions-grid">

            <button
              className="support-action-card"
              onClick={() => { lightTap(); navigate('/raise-refund'); }}
            >
              <span className="material-symbols-outlined">payments</span>
              <span>Raise Refund</span>
            </button>

            <button
              className="support-action-card"
              onClick={() => { lightTap(); navigate('/order-issue'); }}
            >
              <span className="material-symbols-outlined">package_2</span>
              <span>Order Issue</span>
            </button>

            <button
              className="support-action-card"
              onClick={() => { lightTap(); navigate('/payment-issue'); }}
            >
              <span className="material-symbols-outlined">credit_card</span>
              <span>Payment Issue</span>
            </button>

            <button className="support-action-card primary">
              <span className="material-symbols-outlined">headset_mic</span>
              <span>Chat With Us</span>
            </button>

          </div>

        </section>

        {/* Active Tickets */}

        <section className="support-section">

          <div className="support-section-header">

            <h3 className="support-section-title">
              Active Tickets
            </h3>

          </div>

          <div className="support-tickets-list">

            {loading ? (

              <div className="support-loading">
                Loading tickets...
              </div>

            ) : tickets.length > 0 ? (

              tickets.map(ticket => {

                const statusTag =
                  getStatusTag(ticket.ticketStatus);

                return (

                  <div
                    className="support-ticket-card"
                    key={ticket.ticketId}
                  >

                    <div className="support-ticket-accent"></div>

                    <div className="support-ticket-header">

                      <div>

                        <div className="support-ticket-meta">

                          <span className="support-ticket-id">
                            {ticket.ticketNumber || ticket.ticketId}
                          </span>

                          <span className="support-ticket-time">
                            • {ticket.createdAt || 'Recently'}
                          </span>

                        </div>

                        <h4 className="support-ticket-title">
                          {ticket.issueType}
                        </h4>

                      </div>

                      <span
                        className={`support-ticket-status ${statusTag.class}`}
                      >
                        {statusTag.label}
                      </span>

                    </div>

                    <div className="support-ticket-update">

                      <div className="support-pulse-dot-container">
                        <span className="support-pulse-ring"></span>
                        <span className="support-pulse-dot"></span>
                      </div>

                      <p className="support-ticket-desc">
                        {ticket.description ||
                          "Support team is reviewing your request."}
                      </p>

                    </div>

                  </div>

                );

              })

            ) : (

              <div className="support-empty">

                <span className="material-symbols-outlined">
                  assignment_turned_in
                </span>

                <p>No active tickets.</p>

              </div>

            )}

          </div>

        </section>

      </main>

      {/* Bottom Navigation */}

      <nav className="home-bottom-nav">

        <div className="home-bottom-nav-inner">

          <Link
            to="/home"
            className="home-nav-item"
            onClick={lightTap}
          >
            <span className="material-symbols-outlined">home</span>
            <span>Home</span>
          </Link>

          <Link
            to="/discover"
            className="home-nav-item"
            onClick={lightTap}
          >
            <span className="material-symbols-outlined">explore</span>
            <span>Discover</span>
          </Link>

          <Link
            to="/orders"
            className="home-nav-item"
            onClick={lightTap}
          >
            <span className="material-symbols-outlined">
              receipt_long
            </span>
            <span>Orders</span>
          </Link>

          <Link
            to="/profile"
            className="home-nav-item"
            onClick={lightTap}
          >
            <span className="material-symbols-outlined">person</span>
            <span>Profile</span>
          </Link>

        </div>

      </nav>

    </div>

  );

};

export default Support;