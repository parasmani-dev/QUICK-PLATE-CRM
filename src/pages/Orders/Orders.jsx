import { useEffect, useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import axios from 'axios';
import useHaptic from '../../hooks/useHaptic';
import '../Home/Home.css';
import './Orders.css';

import imgMorningBliss from '../../assets/images/MissMatched_Pics/Morning Bliss Bakery.avif';
import imgNapoliWoodfired from '../../assets/images/MissMatched_Pics/Napoli Woodfired Pizza.avif';
import imgSliceStone from '../../assets/images/MissMatched_Pics/Slice & Stone.avif';
import imgSmashStack from '../../assets/images/MissMatched_Pics/Smash & Stack Burgers.avif';
import imgSweetTooth from '../../assets/images/MissMatched_Pics/Sweet Tooth Confections.avif';
import imgMeltdownGrill from '../../assets/images/MissMatched_Pics/The Meltdown Grill.avif';
import imgTokyoNights from '../../assets/images/MissMatched_Pics/Tokyo Nights Rollhous.avif';
import imgZenSushi from '../../assets/images/MissMatched_Pics/Zen Sushi Lounge.avif';
import sushiPlatter from '../../assets/images/sushi-platter.png';

const IMG = {
  pasta:   'https://lh3.googleusercontent.com/aida-public/AB6AXuA7rRqrqQB8WlaPGEnNWpyhdP-PJiwWeP9SL--8b8mCFbqKRAp8ySZBcYOpWC_osbofXS3FhMghzEXj1WzAaysflWk79zTtw2OoN2T4ee7Pn11Vz1rp70xvF0DrnMANaRwY0eY_NkDxVjU6sWQZnxB2xST9n-j0F9KjFKd0_F3y0AAb6T6FGtcLSf9_fTcnrVht3s_SleVk3_bbyLHzFFgZfcamgnzB2vShoIxaY7XRlH3T-419ipyigS7bRFKP0kNFoG0G5NrpCN_K',
  grill:   'https://lh3.googleusercontent.com/aida-public/AB6AXuDRVg4WHeLML4GR_FT_Qw2vnFTiy1T2ux5QaExfnIcN-9F5ma-BjKPAo0Qw7V_C2vQqA3UsAkfzKR5h7oAGr5lT4FN9Nui8lhC2Qal40qJvGanldNT3FvbzyVUMbAkvSOoDmsMfY0QHgkZOjWPpEdWXjwQxDotyzhlPzhpK9rB3i9gL076JH9wnsX5SHq_NS0dEWW7UIs5a4TIM86doVTMv5orv5tGlXzV0OZFq8laVjkiJW3WSdzMBtaCEgOMGTfabbkykSkvUp17R',
  sushi:   sushiPlatter,
  burger:  'https://lh3.googleusercontent.com/aida-public/AB6AXuBIVLq7cg2DsY4Dw1Dv-N3mH1ev7hGiwMSEtAkMb41GEGZ3NWK7evAuqaBMyAPxKkiWfWKvgy0nDn19gJTl36RHd5hphjpBZEHwnD5zk20Xz3OOqpcEORX-TSKWVxR8Sq03vPIHUrMBpMSwfx8YauQJCYaM9mvF_O0B0wiiuU6A1tz_aSdynsxPxodhs5brxxdbojLh_t-ic0gUZNfT-lRUTmhxPYdl_r1BhB55YUDUtCc1hXK1RrtsjFHPykKJvwn2ChzHDcNNp9Px',
  dessert: 'https://lh3.googleusercontent.com/aida-public/AB6AXuBOhl1yjOKt_cFiqW9w_vcZMp1dEUEqSkIF_1PZ2iIkZrAMPdZWmq5nS0UsAxyiyLEANe-rPR00vzNRPE7gtW5F_ZxagryLxi0ew6lKQX3HlNyzqu5iDJHCJ5K-lyvjvro7takNhJHZXCemHKBQWECAbNr0M7UqsYN56Y7IwMX3szaterAKcLL9gjnTAhk1Z5X2ZjsrOEQUEbt_qilhyYQDuwE2oaBRpNEGotfphSL4XSiYM5zKYG8L2ce2Prupm8XZIwamR4fa9m0p',
  salad:   'https://lh3.googleusercontent.com/aida-public/AB6AXuBZH03LnZFjClUcB8auLGFe4iXGTZKPwtoc_7earTpfFLFpyJCZs0HnZvrIO9lRdlin_owGopgjo-eMqf8FxKWEdpRN11FShwLWF9Z7l7FV4qhusFk-YM9Ks3x-rR0l5pwRW6qQw9GcaCIK3IqOd9Nz0uQQzjdk9sAMRsSGOCpGXdvHjngM0ys6JcRfgZOyFuc2oxVMdee-vgSsOXFYq0vfqrhchkpb3dIRU1wD8DmpC7q6DlUQgQqjy4q2ZHuM5uOaqz6FmsWuOjuR',
  masala:  'https://images.unsplash.com/photo-1565557623262-b51c2513a641?q=80&w=2571&auto=format&fit=crop',
  tart:    'https://images.unsplash.com/photo-1488477181946-6428a0291777?q=80&w=2574&auto=format&fit=crop',
  pastry:  'https://images.unsplash.com/photo-1509365465985-25d11c17e812?q=80&w=2630&auto=format&fit=crop',
  cake:    'https://images.unsplash.com/photo-1621303837174-89787a7d4729?q=80&w=2536&auto=format&fit=crop',
};

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || '';
const isMockMode = !API_BASE_URL;

const MOCK_ORDERS = [
  {
    id: '88241',
    restaurantName: "Joe's Pizza",
    date: 'Preparing • Estimated 12 mins',
    total: 35.50,
    status: 'ON_THE_WAY', // Active order
    image: 'https://lh3.googleusercontent.com/aida-public/AB6AXuBmaoj9PogoCQf6PHxcMgiOcQy-P9_pk4_WOxoaqVktCakcWG2GhCfQ8bSy-JfCzk3lHYjkOhL3jLMlbVurUe__EUfHdnRPmoRlMIOC7vMso-aM3K8xa9lFJEJQDCwdTlJDUgjyO4JBG0OrH5YWoIUb7Cq2LTEipBMId1nCvUM3ZdhQruNggs5fXkdbfMWYPSCGG_AQBaPIOGrymg5GWT3RMuiuBRbsKyIdwoguVtbusy71IcxhmLx9dGh0K6zHq4rACAGZTcvxdzrW'
  },
  {
    id: 'ORD-8842',
    restaurantName: 'The Burger Joint',
    date: '#ORD-8842 • Oct 14, 2023',
    total: 42.00,
    status: 'REFUND_PROCESSING',
    image: 'https://lh3.googleusercontent.com/aida-public/AB6AXuBmBKw1BoFpHKZAqyOXDU03NwV9AubjTUY-IlLv9Ffe96C1uyIAd9Rwn-beyvHHm8sAu3Ix18smQtMyyNXt0iKuPCkwTEa0sZtRRUnWAskyZL6UiqoCRKy-33nOLWQOx0a-uL3IE9W-IK1mX5z6osvOaU83HYpJCOJYNAIHsj_qrmQEuQopGaXigulUncFANIoun0Ua5VVBnZ0ujiaazMurMWNLw6VfC6cVoIbKw7tFhTAhDw97_f5k8mdHhaG_troUnNbRS4bWenhK',
    ticket: {
        reportedAt: 'Oct 14, 7:15 PM',
        approvedAt: 'Oct 14, 8:45 PM',
        releasedAt: 'Estimated 3-5 days'
    }
  },
  {
    id: 'ORD-9921',
    restaurantName: 'Sushi Zen - Omakase',
    date: 'Order #ORD-9921 • Delivered Oct 12',
    total: 124.50,
    status: 'DELIVERED',
    image: 'https://lh3.googleusercontent.com/aida-public/AB6AXuDCXw53XVmKro2HruuXClMQnXoeJ5E2HVpYRNt9pN4q-krWmdNyv2d-0qYM-2Sx4X__TqpoxplOLokK2xm0x93RA8lWmnmch5LfVqoV7eYyNJIDBFQusOa-OvZau0_dQdL7ormdMP0obUDKePlOHColI5mtqV_ukkX9QuOmFW4lD-aglUDAcMprscKwYhZHzeDITsiEK_ZEYPCHV8_NuItfyuIs792uwRN--xk1pyvrfB32OyI-l-gRk4zD3R4Jeh8xFeOmKJsq8olb'
  },
  {
    id: 'ORD-7712',
    restaurantName: "Luigi's Pizzeria",
    date: 'Order #ORD-7712 • Oct 08',
    total: 32.00,
    status: 'REFUNDED',
    image: 'https://lh3.googleusercontent.com/aida-public/AB6AXuBmaoj9PogoCQf6PHxcMgiOcQy-P9_pk4_WOxoaqVktCakcWG2GhCfQ8bSy-JfCzk3lHYjkOhL3jLMlbVurUe__EUfHdnRPmoRlMIOC7vMso-aM3K8xa9lFJEJQDCwdTlJDUgjyO4JBG0OrH5YWoIUb7Cq2LTEipBMId1nCvUM3ZdhQruNggs5fXkdbfMWYPSCGG_AQBaPIOGrymg5GWT3RMuiuBRbsKyIdwoguVtbusy71IcxhmLx9dGh0K6zHq4rACAGZTcvxdzrW'
  }
];

const getMappedImage = (restaurantName) => {
  if (!restaurantName) return MOCK_ORDERS[0].image;
  if (restaurantName.includes("Morning Bliss")) return imgMorningBliss;
  if (restaurantName.includes("Napoli Woodfired")) return imgNapoliWoodfired;
  if (restaurantName.includes("Slice & Stone")) return imgSliceStone;
  if (restaurantName.includes("Smash & Stack")) return imgSmashStack;
  if (restaurantName.includes("Sweet Tooth")) return imgSweetTooth;
  if (restaurantName.includes("Meltdown Grill")) return imgMeltdownGrill;
  if (restaurantName.includes("Tokyo Nights")) return imgTokyoNights;
  if (restaurantName.includes("Zen Sushi")) return imgZenSushi;
  if (restaurantName.includes("Grill")) return IMG.grill;
  if (restaurantName.includes("Masala")) return IMG.masala;
  if (restaurantName.includes("Sakura") || restaurantName.includes("Omakase")) return IMG.sushi;
  if (restaurantName.includes("Smokehouse")) return IMG.burger;
  if (restaurantName.includes("Green & Grain")) return IMG.salad;
  return MOCK_ORDERS[0].image;
};

const Orders = () => {
  const navigate = useNavigate();
  const { lightTap, mediumTap } = useHaptic();
  
  const [orders, setOrders] = useState([]);
  const [supportTickets, setSupportTickets] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchOrders = async () => {
      try {
        if (isMockMode) {
          await new Promise(r => setTimeout(r, 600));
          setOrders(MOCK_ORDERS);
        } else {
          try {
            const storedUser = JSON.parse(localStorage.getItem('quickplate_user') || '{}');
            const customerId = storedUser?.customerId;
            if (!customerId) {
              console.warn("No customer ID found. Cannot fetch orders.");
              setOrders([]);
              return;
            }
            const res = await axios.get(`${API_BASE_URL}/services/apexrest/customer/orders?customerId=${customerId}`);
            if (res.data && res.data.length > 0) {
              const mappedData = res.data.map(item => {
                const restaurantName = item.restaurantName || item.restaurantName || 'Quick Plate Order';
                return {
                  id: item.Id || item.id || 'N/A',
                  restaurantName: restaurantName,
                  date: item.CreatedDate ? new Date(item.CreatedDate).toLocaleDateString() : item.date || 'Today',
                  total: item.totalAmount || item.total || 0,
                  status: item.orderStatus || item.status || 'PLACED',
                  paymentStatus: item.paymentStatus || item.paymentStatus || '',
                  image: item.image || getMappedImage(restaurantName)
                };
              });
              setOrders(mappedData);
            } else {
              setOrders([]);
            }
          } catch(e) {
            console.warn("Backend fetch failed", e);
            setOrders([]);
          }
        }
      } catch (err) {
        console.error('Error fetching orders:', err);
      } finally {
        const tickets = JSON.parse(localStorage.getItem('supportTickets') || '[]');
        setSupportTickets(tickets);
        setLoading(false);
      }
    };
    fetchOrders();
  }, []);

  const handleTrackOrder = (orderId) => {
    mediumTap();
    navigate(`/tracking/${orderId}`);
  };

  const activeStatuses = ['ON_THE_WAY', 'PLACED', 'Payment Succeeded', 'CONFIRMED', 'PREPARING', 'ASSIGNED', 'PICKED_UP', 'OUT_FOR_DELIVERY'];
  const activeOrders = orders.filter(order => activeStatuses.includes(order.status) || order.paymentStatus === 'Payment Succeeded');
  const refundProcessingOrders = orders.filter(order => order.status === 'REFUND_PROCESSING' || order.status === 'Refund Processing');
  const pastOrders = orders.filter(order => order.status === 'DELIVERED' || order.status === 'Delivered' || order.status === 'REFUNDED').slice(0, 8);

  return (
    <div className="orders-layout bg-background-light dark:bg-background-dark">
      {/* ─── Header ─── */}
      <header className="sticky top-0 z-20 bg-background-light/90 dark:bg-slate-900/90 backdrop-blur-md px-6 py-5 flex items-center justify-between">
        <div className="flex items-center gap-4">
          <span onClick={() => { lightTap(); navigate(-1); }} className="material-symbols-outlined text-primary cursor-pointer font-bold">arrow_back_ios</span>
          <h1 className="text-xl font-bold tracking-tight text-slate-800 dark:text-white">Order History</h1>
        </div>
        <button className="bg-primary/5 p-2.5 rounded-full text-primary hover:bg-primary/10 transition-colors" onClick={lightTap}>
          <span className="material-symbols-outlined text-[22px]">search</span>
        </button>
      </header>

      <div className="px-6 mb-2 mt-2">
        <div className="flex bg-slate-100 dark:bg-slate-800/50 p-1.5 rounded-2xl">
          <button className="flex-1 bg-primary text-white py-2.5 rounded-xl text-sm font-bold shadow-md shadow-primary/20 transition-all">Past Orders</button>
          <button className="flex-1 text-slate-500 dark:text-slate-400 py-2.5 text-sm font-semibold transition-all">Support Tickets</button>
        </div>
      </div>

      {/* ─── Main Content ─── */}
      <main className="orders-main">
        {loading ? (
          <div className="orders-loading">
            <div className="orders-spinner" />
          </div>
        ) : (
          <div className="orders-sections-container">
            {/* CURRENT ORDER SECTION */}
            {activeOrders.length > 0 && (
              <section className="mb-8">
                <h2 className="text-lg font-bold text-slate-800 dark:text-white mb-4">Current Order</h2>
                <div className="flex flex-col gap-4">
                  {activeOrders.map((order) => (
                    <div key={order.id} className="bg-white dark:bg-slate-900 rounded-xl p-5 border border-orange-100 dark:border-slate-800" style={{ boxShadow: '0 10px 30px -10px rgba(0,0,0,0.05)' }}>
                      <div className="flex gap-4 mb-4">
                        <div className="w-20 h-20 rounded-full bg-center bg-cover shrink-0" style={{ backgroundImage: `url('${order.image}')`, boxShadow: '0 10px 30px -10px rgba(0,0,0,0.05)' }} />
                        <div className="flex-1">
                          <div className="flex justify-between items-start">
                            <h3 className="font-bold text-slate-800 dark:text-white">{order.restaurantName}</h3>
                            <span className="font-bold text-slate-900 dark:text-white">${typeof order.total === 'number' ? order.total.toFixed(2) : order.total}</span>
                          </div>
                          <p className="text-slate-400 text-xs mt-1">Order #{order.id} • {order.date}</p>
                          
                          <div className="mt-2 inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-orange-50 text-orange-600 dark:bg-orange-900/20 dark:text-orange-400 text-[10px] font-bold uppercase tracking-wider">
                            <span className="material-symbols-outlined text-[14px]">
                              {['DELIVERED', 'Delivered'].includes(order.status) ? 'check_circle' : 'local_shipping'}
                            </span>
                            {order.status === 'Payment Succeeded' || order.paymentStatus === 'Payment Succeeded' ? 'Payment Succeeded' : (
                                ['CONFIRMED', 'PREPARING', 'ASSIGNED', 'PICKED_UP', 'OUT_FOR_DELIVERY', 'ON_THE_WAY', 'PLACED'].includes(order.status) ? order.status.replace(/_/g, ' ') : order.status
                            )}
                          </div>
                        </div>
                      </div>
                      
                      <button 
                         className="w-full bg-primary text-white font-bold py-3.5 rounded-xl shadow-lg shadow-orange-500/25 hover:opacity-90 transition-opacity"
                         onClick={() => handleTrackOrder(order.id)}
                      >
                        Track Order
                      </button>
                    </div>
                  ))}
                </div>
              </section>
            )}

            {/* PAST & SUPPORT TICKETS SECTION */}
            {(pastOrders.length > 0 || supportTickets.length > 0 || refundProcessingOrders.length > 0) && (
              <section className="space-y-4">
                <h2 className="text-lg font-bold text-slate-800 dark:text-white">Recent Orders</h2>
                <div className="space-y-4">
                  {/* Local Support Tickets */}
                  {supportTickets.map((ticket) => (
                    <div key={ticket.id} className="bg-white dark:bg-slate-900 rounded-xl p-5 border border-slate-50 dark:border-slate-800" style={{ boxShadow: '0 10px 30px -10px rgba(0,0,0,0.05)' }}>
                      <div className="flex justify-between items-start">
                        <div>
                          <h3 className="font-bold text-slate-800 dark:text-white">{ticket.type ? ticket.restaurantName : `Issue with ${ticket.restaurantName}`}</h3>
                          <p className="text-slate-400 text-xs mt-1">CASE-{ticket.id.replace('CASE-', '').replace('ORD-', '')}</p>
                        </div>
                        <span className="font-bold text-slate-900 dark:text-white">${typeof ticket.total === 'number' ? ticket.total.toFixed(2) : ticket.total}</span>
                      </div>
                      <div className="mt-2 inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-orange-50 text-orange-600 dark:bg-orange-900/20 dark:text-orange-400 text-[10px] font-bold uppercase tracking-wider">
                        <span className="material-symbols-outlined text-[14px]">support_agent</span>
                        {ticket.status || 'UNDER REVIEW'}
                      </div>
                      <p className="text-sm mt-3 text-slate-600 dark:text-slate-400 border-t border-slate-100 dark:border-slate-800 pt-3">
                         {ticket.desc ? ticket.desc : "Our agents are currently reviewing your request."}
                      </p>
                    </div>
                  ))}

                  {/* Refund Processing Orders */}
                  {refundProcessingOrders.map((order) => (
                    <div key={order.id} className="bg-white dark:bg-slate-900 rounded-xl p-5 border border-slate-50 dark:border-slate-800 overflow-hidden relative" style={{ boxShadow: '0 10px 30px -10px rgba(0,0,0,0.05)' }}>
                      <div className="flex justify-between items-start mb-6">
                        <div className="flex gap-4">
                          <div className="w-16 h-16 rounded-full bg-center bg-cover shrink-0" style={{ backgroundImage: `url('${order.image}')` }} />
                          <div>
                            <h3 className="font-bold text-slate-800 dark:text-white">{order.restaurantName}</h3>
                            <p className="text-slate-400 text-xs mt-0.5">#{order.id} • {order.date}</p>
                            <div className="mt-2 inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-blue-50 text-blue-600 dark:bg-blue-900/30 dark:text-blue-300 text-[10px] font-bold uppercase tracking-wider">
                              <span className="material-symbols-outlined text-[14px] animate-spin" style={{ animationDuration: '3s' }}>sync</span>
                              Refund Processing
                            </div>
                          </div>
                        </div>
                        <span className="font-bold text-primary">${typeof order.total === 'number' ? order.total.toFixed(2) : order.total}</span>
                      </div>
                      
                      {/* Ticket Status UI */}
                      <div className="pt-5 border-t border-slate-50 dark:border-slate-800">
                        <div className="flex items-center gap-2 mb-5">
                          <span className="material-symbols-outlined text-[18px] text-slate-400">cloud_done</span>
                          <p className="text-[11px] font-bold text-slate-400 uppercase tracking-widest">Ticket Status (Salesforce Sync)</p>
                        </div>
                        <div className="relative space-y-7 ml-1">
                          <div className="absolute left-[11px] top-2 bottom-2 w-0.5" style={{ background: 'linear-gradient(to bottom, #22c55e 0%, #fb7e18 50%, #e2e8f0 100%)' }}></div>
                          
                          <div className="relative pl-10">
                            <div className="absolute left-0 top-0.5 w-6 h-6 bg-green-500 rounded-full flex items-center justify-center border-4 border-white dark:border-slate-900 shadow-sm z-10">
                              <span className="material-symbols-outlined text-white text-[12px] font-bold">check</span>
                            </div>
                            <div>
                              <p className="text-sm font-bold text-slate-700 dark:text-slate-200">Issue Reported</p>
                              <p className="text-[11px] text-slate-400">{order.ticket?.reportedAt || 'Today, 7:15 PM'}</p>
                            </div>
                          </div>

                          <div className="relative pl-10">
                            <div className="absolute left-0 top-0.5 w-6 h-6 bg-primary rounded-full flex items-center justify-center border-4 border-white dark:border-slate-900 shadow-sm z-10">
                              <span className="material-symbols-outlined text-white text-[12px] font-bold">verified</span>
                            </div>
                            <div>
                              <p className="text-sm font-bold text-slate-700 dark:text-slate-200">Approved for Refund</p>
                              <p className="text-[11px] text-slate-400">{order.ticket?.approvedAt || 'Today, 8:45 PM'}</p>
                            </div>
                          </div>

                          <div className="relative pl-10">
                            <div className="absolute left-0 top-0.5 w-6 h-6 bg-slate-200 dark:bg-slate-800 rounded-full flex items-center justify-center border-4 border-white dark:border-slate-900 z-10">
                              <span className="material-symbols-outlined text-slate-400 dark:text-slate-600 text-[12px]">account_balance_wallet</span>
                            </div>
                            <div className="opacity-50">
                              <p className="text-sm font-bold text-slate-500">Funds Released</p>
                              <p className="text-[11px] text-slate-400">{order.ticket?.releasedAt || 'Estimated 3-5 days'}</p>
                            </div>
                          </div>

                        </div>
                      </div>
                    </div>
                  ))}

                  {/* Delivered Past Orders */}
                  {pastOrders.map((order) => {
                    if (order.status === 'DELIVERED' || order.status === 'Delivered') {
                      return (
                        <div key={order.id} className="bg-white dark:bg-slate-900 rounded-xl p-5 border border-slate-50 dark:border-slate-800" style={{ boxShadow: '0 10px 30px -10px rgba(0,0,0,0.05)' }}>
                          <div className="flex gap-4 mb-4">
                            <div className="w-20 h-20 rounded-full bg-center bg-cover shrink-0" style={{ backgroundImage: `url('${order.image}')` }} />
                            <div className="flex-1">
                              <div className="flex justify-between items-start">
                                <h3 className="font-bold text-slate-800 dark:text-white">{order.restaurantName}</h3>
                                <span className="font-bold text-slate-900 dark:text-white">${typeof order.total === 'number' ? order.total.toFixed(2) : order.total}</span>
                              </div>
                              <p className="text-slate-400 text-xs mt-1">{order.date}</p>
                              <div className="mt-2 inline-flex items-center gap-1 px-3 py-1 rounded-full bg-slate-50 text-slate-500 dark:bg-slate-800 dark:text-slate-400 text-[10px] font-bold uppercase tracking-wider">
                                <span className="material-symbols-outlined text-[14px] text-green-500">check_circle</span>
                                Delivered
                              </div>
                            </div>
                          </div>
                          <div className="flex gap-3">
                            <button className="flex-1 bg-primary text-white text-xs font-bold py-3 rounded-xl shadow-sm hover:opacity-90">Reorder</button>
                            <button className="flex-1 border border-primary/20 text-primary text-xs font-bold py-3 rounded-xl hover:bg-primary/5">Raise Issue</button>
                          </div>
                        </div>
                      );
                    }
                    if (order.status === 'REFUNDED') {
                      return (
                        <div key={order.id} className="bg-white dark:bg-slate-900 rounded-xl p-5 border border-slate-50 dark:border-slate-800" style={{ boxShadow: '0 10px 30px -10px rgba(0,0,0,0.05)' }}>
                          <div className="flex gap-4 mb-4">
                            <div className="w-20 h-20 rounded-full bg-center bg-cover shrink-0" style={{ backgroundImage: `url('${order.image}')` }} />
                            <div className="flex-1">
                              <div className="flex justify-between items-start">
                                <h3 className="font-bold text-slate-800 dark:text-white">{order.restaurantName}</h3>
                                <span className="font-bold line-through text-slate-400">${typeof order.total === 'number' ? order.total.toFixed(2) : order.total}</span>
                              </div>
                              <p className="text-slate-400 text-xs mt-1">{order.date}</p>
                              <div className="mt-2 inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-slate-100 text-slate-600 dark:bg-slate-800 dark:text-slate-400 text-[10px] font-bold uppercase tracking-wider">
                                <span className="material-symbols-outlined text-[14px]">check_circle</span>
                                Refunded
                              </div>
                            </div>
                          </div>
                          <button className="mt-1 w-full border border-slate-200 dark:border-slate-800 text-slate-500 text-xs font-bold py-3 rounded-xl flex items-center justify-center gap-2 hover:bg-slate-50 dark:hover:bg-slate-800">
                             <span className="material-symbols-outlined text-[14px]">receipt_long</span>
                             View Summary
                          </button>
                        </div>
                      );
                    }
                    return null;
                  })}
                </div>
              </section>
            )}

            {/* EMPTY STATE */}
            {activeOrders.length === 0 && supportTickets.length === 0 && refundProcessingOrders.length === 0 && pastOrders.length === 0 && (
              <div style={{ textAlign: 'center', padding: '3rem 1rem', color: '#94a3b8' }}>
                 <span className="material-symbols-outlined" style={{ fontSize: '48px', color: '#cbd5e1', marginBottom: '1rem' }}>receipt_long</span>
                 <p style={{ fontWeight: 600 }}>No orders found.</p>
              </div>
            )}
          </div>
        )}
      </main>

      {/* ─── Bottom Navigation ─── */}
      <nav className="home-bottom-nav">
        <div className="home-bottom-nav-inner">
          <Link to="/home" className="home-nav-item" onClick={lightTap}>
            <span className="material-symbols-outlined">home</span>
            <span className="home-nav-label">Home</span>
          </Link>
          <Link to="/discover" className="home-nav-item" onClick={lightTap}>
            <span className="material-symbols-outlined">explore</span>
            <span className="home-nav-label">Discover</span>
          </Link>
          <Link to="/orders" className="home-nav-item active" onClick={lightTap}>
            <div style={{ position: 'relative' }}>
              <span className="material-symbols-outlined">receipt_long</span>
              <span className="home-nav-badge" />
            </div>
            <span className="home-nav-label">Orders</span>
          </Link>
          <Link to="/profile" className="home-nav-item" onClick={lightTap}>
            <span className="material-symbols-outlined">person</span>
            <span className="home-nav-label">Profile</span>
          </Link>
        </div>
      </nav>
    </div>
  );
};

export default Orders;

