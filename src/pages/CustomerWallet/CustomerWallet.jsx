import { motion } from 'framer-motion';
import { useNavigate } from 'react-router-dom';
import useHaptic from '../../hooks/useHaptic';
import './CustomerWallet.css';

const fadeUp = {
  hidden: { opacity: 0, y: 20 },
  visible: (d = 0) => ({
    opacity: 1, y: 0,
    transition: { delay: d, duration: 0.5, ease: [0.25, 0.46, 0.45, 0.94] },
  }),
};

const CustomerWallet = () => {
  const navigate = useNavigate();
  const { lightTap, mediumTap } = useHaptic();

  return (
    <div className="wallet-page">
      <header className="wallet-header">
        <button className="wallet-back-btn" onClick={() => { lightTap(); navigate(-1); }}>
          <span className="material-symbols-outlined">arrow_back_ios_new</span>
        </button>
        <h1 className="wallet-title">My Wallet</h1>
        <div style={{ width: 24 }} /> {/* Spacer for alignment */}
      </header>

      <main className="wallet-main">
        <motion.div 
          className="wallet-balance-card"
          variants={fadeUp}
          initial="hidden"
          animate="visible"
          custom={0}
        >
          <p className="balance-label">Available Balance</p>
          <h2 className="balance-amount">$0.00</h2>
        </motion.div>

        <motion.div 
          className="wallet-actions"
          variants={fadeUp}
          initial="hidden"
          animate="visible"
          custom={0.1}
        >
          <button className="action-btn" onClick={mediumTap}>
            <div className="action-icon">
              <span className="material-symbols-outlined">add</span>
            </div>
            <span>Add Funds</span>
          </button>
          <button className="action-btn" onClick={mediumTap}>
            <div className="action-icon">
              <span className="material-symbols-outlined">payments</span>
            </div>
            <span>Withdraw</span>
          </button>
        </motion.div>

        <motion.div 
          className="recent-activity"
          variants={fadeUp}
          initial="hidden"
          animate="visible"
          custom={0.2}
        >
          <h3 className="activity-title">Recent Activity</h3>
          <div className="empty-state">
             <span className="material-symbols-outlined">receipt_long</span>
             <p>No recent wallet transactions.</p>
          </div>
        </motion.div>
      </main>
    </div>
  );
};

export default CustomerWallet;
