#!/usr/bin/env ruby
require 'json'

data = JSON.parse(File.read(File.join(__dir__, '..', 'data', 'initial_data.json')))
initial_data_js = JSON.pretty_generate(data)

template = <<~'JSX'
import { useState, useEffect, useRef, useMemo } from 'react';

const VER = 'dashboard-v02';

const fmt = n => n >= 100000 ? `₹${(n/100000).toFixed(2)}L` : n >= 1000 ? `₹${(n/1000).toFixed(1)}K` : `₹${Math.round(n)}`;
const fmtF = n => `₹${Number(n).toLocaleString('en-IN')}`;
const monthMap = {Jan:1,Feb:2,Mar:3,Apr:4,May:5,Jun:6,Jul:7,Aug:8,Sep:9,Oct:10,Nov:11,Dec:12};
const parseDate = d => { const [dd,m]=d.split('-'); return (monthMap[m]||0)*100+parseInt(dd,10); };

const INITIAL_DATA = __INITIAL_DATA__;

const storage = {
  async get(key) {
    if (window.storage?.get) return window.storage.get(key);
    try { return localStorage.getItem(key); } catch { return null; }
  },
  async set(key, val) {
    if (window.storage?.set) return window.storage.set(key, val);
    try { localStorage.setItem(key, val); } catch {}
  }
};

const TABS = [
  { icon: '📊', label: 'Overview' },
  { icon: '🏪', label: 'Vendors' },
  { icon: '📦', label: 'Materials' },
  { icon: '💳', label: 'Payments' },
  { icon: '🥧', label: 'Breakdown' },
];

function Donut({ categories, total, dark }) {
  const r = 44, cx = 55, cy = 55, sw = 14, circ = 2 * Math.PI * r;
  let offset = 0;
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
      <svg viewBox="0 0 110 110" width={110} height={110}>
        <circle cx={cx} cy={cy} r={r} fill="none" stroke={dark ? '#2c2c2e' : '#e5e5ea'} strokeWidth={sw} />
        {categories.map((c, i) => {
          const pct = total > 0 ? c.amt / total : 0;
          const dash = pct * circ;
          const el = (
            <circle key={i} cx={cx} cy={cy} r={r} fill="none" stroke={c.color} strokeWidth={sw}
              strokeDasharray={`${dash} ${circ - dash}`} strokeDashoffset={-offset}
              transform={`rotate(-90 ${cx} ${cy})`} />
          );
          offset += dash;
          return el;
        })}
        <text x={cx} y={cy - 4} textAnchor="middle" fill={dark ? '#f2f2f7' : '#1c1c1e'} fontSize="11" fontWeight="700">{fmt(total)}</text>
        <text x={cx} y={cy + 10} textAnchor="middle" fill={dark ? '#98989d' : '#636366'} fontSize="8">Total</text>
      </svg>
      <div style={{ flex: 1 }}>
        {categories.slice(0, 6).map(c => (
          <div key={c.name} style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 4, fontSize: 10 }}>
            <span style={{ width: 8, height: 8, borderRadius: 4, background: c.color, flexShrink: 0 }} />
            <span style={{ flex: 1, color: 'var(--txt2)' }}>{c.name}</span>
            <span style={{ fontWeight: 600, fontVariantNumeric: 'tabular-nums' }}>{c.pct}%</span>
          </div>
        ))}
      </div>
    </div>
  );
}

export default function HomeConstructionDashboard() {
  const [data, setData] = useState(null);
  const [tab, setTab] = useState(0);
  const [dark, setDark] = useState(true);
  const [noteEdit, setNoteEdit] = useState(false);
  const [expandedMat, setExpandedMat] = useState(null);
  const [expandedVendor, setExpandedVendor] = useState(null);
  const [expandedCat, setExpandedCat] = useState(null);
  const [payMonth, setPayMonth] = useState(null);
  const noteRef = useRef(null);

  useEffect(() => {
    (async () => {
      const raw = await storage.get(VER);
      if (raw) {
        try { setData(JSON.parse(raw)); return; } catch {}
      }
      setData(INITIAL_DATA);
    })();
  }, []);

  const save = async (next) => {
    setData(next);
    await storage.set(VER, JSON.stringify(next));
  };

  const theme = dark ? {
    bg: '#000', s1: '#1c1c1e', s2: '#2c2c2e', s3: '#3a3a3c',
    txt: '#f2f2f7', txt2: '#98989d', txt3: '#636366', sep: 'rgba(84,84,88,0.25)', expBg: '#111',
    noteBg: '#1b3a1f', noteBorder: '#4ade80', noteText: '#4ade80'
  } : {
    bg: '#f2f2f7', s1: '#fff', s2: '#f0f0f5', s3: '#e5e5ea',
    txt: '#1c1c1e', txt2: '#636366', txt3: '#aeaeb2', sep: 'rgba(60,60,67,0.12)', expBg: '#f8f8fa',
    noteBg: '#e8f5e9', noteBorder: '#34c759', noteText: '#1b7a2b'
  };

  const allPayments = useMemo(() => {
    if (!data) return [];
    const list = [];
    data.payers.forEach(p => p.payments.forEach(pm => list.push({ ...pm, payer: p.name, payerColor: p.color })));
    return list.sort((a, b) => parseDate(b.date) - parseDate(a.date));
  }, [data]);

  const monthGroups = useMemo(() => {
    const map = {};
    allPayments.forEach(p => {
      const [, mon] = p.date.split('-');
      const yr = mon === 'May' ? '2026' : '2026';
      const key = `${mon} ${yr}`;
      map[key] = map[key] || { total: 0, count: 0, items: [] };
      map[key].total += p.amt;
      map[key].count += 1;
      map[key].items.push(p);
    });
    return Object.entries(map).sort((a, b) => {
      const order = ['Jun','May','Apr','Mar','Feb','Jan','Jul','Aug','Sep','Oct','Nov','Dec'];
      return order.indexOf(a[0].split(' ')[0]) - order.indexOf(b[0].split(' ')[0]);
    });
  }, [allPayments]);

  useEffect(() => {
    if (noteRef.current) {
      noteRef.current.style.height = 'auto';
      noteRef.current.style.height = noteRef.current.scrollHeight + 'px';
    }
  }, [noteEdit, data?.notes]);

  if (!data) return <div style={{ padding: 40, textAlign: 'center', color: '#98989d' }}>Loading…</div>;

  const maxMat = Math.max(...data.materials.map(m => m.amt), 1);
  const payerTotal = data.payers.reduce((s, p) => s + p.amount, 0) || 1;
  const noteLines = (data.notes || '').split('\n').filter((_, i, a) => i < a.length);

  const card = { background: theme.s1, borderRadius: 14, border: `0.5px solid ${theme.sep}`, padding: '12px 14px' };
  const th = { fontSize: 9, color: theme.txt3, textTransform: 'uppercase', padding: '4px 6px', fontWeight: 600 };
  const td = { fontSize: 10, color: theme.txt, padding: '6px 6px', fontVariantNumeric: 'tabular-nums' };

  const renderOverview = () => (
    <div style={{ padding: '12px 14px 80px' }}>
      {data.alerts.map((a, i) => (
        <div key={i} style={{
          background: a.type === 'orange' ? 'linear-gradient(135deg, #ff8c00, #ff6b00)' : 'linear-gradient(135deg, #4a90d9, #357abd)',
          borderRadius: 14, padding: '12px 14px', marginBottom: 10
        }}>
          <div style={{ fontSize: 13, fontWeight: 700, color: '#fff', marginBottom: 4 }}>{a.title}</div>
          <div style={{ fontSize: 11, color: '#ffffff', lineHeight: 1.4 }}>{a.desc}</div>
        </div>
      ))}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, marginBottom: 14 }}>
        {[
          { icon: '💰', label: 'Total Spent', val: fmt(data.kpis.totalPaid), sub: 'All payments' },
          { icon: '📦', label: 'On Site', val: fmt(data.kpis.materialBilled), sub: 'Material billed' },
          { icon: '🧱', label: 'Advance', val: fmt(data.kpis.vendorAdvance), sub: 'Brick advance left', color: '#ff9500' },
          { icon: '⚠️', label: 'Pending', val: fmt(data.kpis.pending), sub: 'Vendor balance due', color: '#ff3b30' },
        ].map((k, i) => (
          <div key={i} style={card}>
            <div style={{ fontSize: 16 }}>{k.icon}</div>
            <div style={{ fontSize: 9, color: theme.txt3, textTransform: 'uppercase', marginTop: 4 }}>{k.label}</div>
            <div style={{ fontSize: 20, fontWeight: 700, color: k.color || theme.txt, fontVariantNumeric: 'tabular-nums' }}>{k.val}</div>
            <div style={{ fontSize: 9, color: theme.txt3 }}>{k.sub}</div>
          </div>
        ))}
      </div>
      <div style={card}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
          <span style={{ fontWeight: 700, fontSize: 13 }}>📝 Notes</span>
          <div style={{ display: 'flex', gap: 8 }}>
            <button onClick={() => setNoteEdit(!noteEdit)} style={{ background: 'none', border: 'none', color: '#007aff', fontSize: 12, cursor: 'pointer' }}>✏️</button>
            <button onClick={() => save({ ...data, notes: '' })} style={{ background: 'none', border: 'none', color: '#ff3b30', fontSize: 12, cursor: 'pointer' }}>🗑️</button>
          </div>
        </div>
        <div style={{ background: theme.noteBg, border: `1px solid ${theme.noteBorder}`, borderRadius: 10, padding: 10, position: 'relative' }}>
          {noteEdit ? (
            <textarea ref={noteRef} value={data.notes || ''} onChange={e => save({ ...data, notes: e.target.value })}
              style={{ width: '100%', background: 'transparent', border: 'none', color: theme.txt, fontSize: 12, lineHeight: 1.6, resize: 'none', overflow: 'hidden', outline: 'none', fontFamily: 'inherit' }} />
          ) : noteLines.length ? noteLines.map((line, i) => (
            <div key={i} style={{ fontSize: 12, lineHeight: 1.6, color: theme.txt }}>
              <span style={{ color: theme.noteText, fontWeight: 600, marginRight: 6 }}>{i + 1}.</span>{line}
            </div>
          )) : <div style={{ fontSize: 12, color: theme.txt3 }}>No notes — tap ✏️</div>}
        </div>
      </div>
    </div>
  );

  const renderVendors = () => (
    <div style={{ padding: '12px 14px 80px' }}>
      {data.vendors.action.length > 0 && (
        <>
          <div style={{ color: '#ff3b30', fontWeight: 700, fontSize: 12, marginBottom: 8 }}>⚠️ Action Needed</div>
          {data.vendors.action.map((v, i) => (
            <div key={i} style={{ ...card, marginBottom: 8 }}>
              <div style={{ fontWeight: 700, fontSize: 13 }}>{v.name}</div>
              <div style={{ fontSize: 10, color: theme.txt2 }}>{v.cat}</div>
              <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 6 }}>
                <span style={{ fontSize: 11, color: theme.txt2 }}>Paid {fmt(v.paid)}</span>
                <span style={{ fontSize: 10, fontWeight: 700, color: '#ff9500', background: 'rgba(255,149,0,0.15)', padding: '2px 8px', borderRadius: 8 }}>{v.badge}</span>
              </div>
            </div>
          ))}
        </>
      )}
      <div style={{ color: theme.txt, fontWeight: 700, fontSize: 12, margin: '14px 0 8px' }}>🧱 Brick Delivery Tracker</div>
      <div style={card}>
        <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 8 }}>
          <span style={{ fontWeight: 700 }}>🧱 Brick Company</span>
          <span style={{ color: '#ff9500', fontWeight: 700, fontSize: 12 }}>{data.vendors.brick.pct}% Delivered</span>
        </div>
        {[['Total Advance', fmt(data.vendors.brick.advance)], ['Bricks Received', data.vendors.brick.received.toLocaleString('en-IN')], ['Est. Total Order', data.vendors.brick.total.toLocaleString('en-IN')], ['Rate', `₹${data.vendors.brick.rate}`]].map(([l, v]) => (
          <div key={l} style={{ display: 'flex', justifyContent: 'space-between', fontSize: 11, marginBottom: 4 }}>
            <span style={{ color: theme.txt2 }}>{l}</span><span style={{ fontWeight: 600 }}>{v}</span>
          </div>
        ))}
        <div style={{ height: 8, background: theme.s2, borderRadius: 4, margin: '8px 0', overflow: 'hidden' }}>
          <div style={{ width: `${data.vendors.brick.pct}%`, height: '100%', background: 'linear-gradient(90deg, #ff6b35, #ff9500)', borderRadius: 4 }} />
        </div>
        <div style={{ fontSize: 10, color: theme.txt3 }}>{data.vendors.brick.received.toLocaleString('en-IN')} delivered of ~{data.vendors.brick.total.toLocaleString('en-IN')}</div>
      </div>
      <div style={{ color: theme.txt, fontWeight: 700, fontSize: 12, margin: '14px 0 8px' }}>🚜 Mitti Delivery Tracker</div>
      <div style={card}>
        <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 8 }}>
          <span style={{ fontWeight: 700 }}>🚜 Mukesh Yadav — Mitti</span>
          <span style={{ color: '#ff9500', fontWeight: 700 }}>{data.vendors.mitti.totalTrailers} Trailers</span>
        </div>
        {[['Batch 1', `${data.vendors.mitti.batch1} trailers`], ['Batch 2', `${data.vendors.mitti.batch2} trailers`], ['Total', data.vendors.mitti.totalTrailers], ['Rate', `₹${data.vendors.mitti.rate}`], ['Total Cost', fmt(data.vendors.mitti.totalCost)], ['Paid', fmt(data.vendors.mitti.paid)], ['Balance Due', fmt(data.vendors.mitti.totalCost - data.vendors.mitti.paid)]].map(([l, v]) => (
          <div key={l} style={{ display: 'flex', justifyContent: 'space-between', fontSize: 11, marginBottom: 4 }}>
            <span style={{ color: theme.txt2 }}>{l}</span><span style={{ fontWeight: 600, color: l === 'Balance Due' ? '#ff3b30' : theme.txt }}>{v}</span>
          </div>
        ))}
      </div>
      <div style={{ color: theme.txt3, fontSize: 11, margin: '14px 0 8px' }}>✅ Settled — tap to expand</div>
      {data.vendors.settled.map((v, i) => (
        <div key={i} style={{ ...card, marginBottom: 8, cursor: 'pointer' }} onClick={() => setExpandedVendor(expandedVendor === i ? null : i)}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <span style={{ flex: 1, fontWeight: 700, fontSize: 13 }}>{v.name}</span>
            <span style={{ fontSize: 11, fontWeight: 600 }}>{fmt(v.amt)}</span>
            <span style={{ transform: expandedVendor === i ? 'rotate(90deg)' : 'none', transition: 'transform .2s', color: theme.txt3 }}>›</span>
          </div>
          <div style={{ fontSize: 10, color: theme.txt2 }}>{v.cat}</div>
          <span style={{ fontSize: 9, color: '#34c759', fontWeight: 700 }}>PAID</span>
          {expandedVendor === i && (
            <div style={{ marginTop: 10, background: theme.expBg, borderRadius: 8, overflow: 'hidden' }}>
              <table style={{ width: '100%', borderCollapse: 'collapse' }}>
                <thead><tr>{['DATE','ITEM','QTY','RATE','TOTAL'].map(h => <th key={h} style={th}>{h}</th>)}</tr></thead>
                <tbody>
                  {v.items.map((it, j) => (
                    <tr key={j}>
                      <td style={td}>{it.date}</td>
                      <td style={{ ...td, maxWidth: 100 }}>{it.item}{it.note ? <div style={{ fontStyle: 'italic', fontSize: 9, color: theme.txt3 }}>📝 {it.note}</div> : null}</td>
                      <td style={td}>{it.qty} {it.unit}</td>
                      <td style={td}>{it.rate}</td>
                      <td style={{ ...td, color: '#007aff' }}>{fmtF(it.total)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
              <div style={{ padding: 8, fontSize: 10, fontWeight: 700, textAlign: 'right' }}>Total ({v.items.length} items) {fmtF(v.amt)}</div>
            </div>
          )}
        </div>
      ))}
    </div>
  );

  const renderMaterials = () => (
    <div style={{ padding: '12px 14px 80px' }}>
      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', fontSize: 9, color: theme.txt3, marginBottom: 12 }}>
        <span><span style={{ color: '#ff6b35' }}>■</span> Building</span>
        <span><span style={{ color: '#888' }}>■</span> Steel</span>
        <span><span style={{ color: '#007aff' }}>■</span> Cement</span>
        <span><span style={{ color: '#30b0c7' }}>■</span> Chemical</span>
        <span><span style={{ color: '#636366' }}>■</span> Other</span>
      </div>
      {data.materials.map((m, i) => (
        <div key={i} style={{ ...card, marginBottom: 8, cursor: 'pointer' }} onClick={() => setExpandedMat(expandedMat === i ? null : i)}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <span style={{ flex: 1, fontWeight: 600, fontSize: 12 }}>{m.name}</span>
            <span style={{ fontWeight: 700, fontSize: 12 }}>{fmt(m.amt)}</span>
            <span style={{ transform: expandedMat === i ? 'rotate(90deg)' : 'none', transition: 'transform .2s', color: theme.txt3 }}>›</span>
          </div>
          <div style={{ fontSize: 10, color: theme.txt2, marginBottom: 6 }}>{m.detail}</div>
          <div style={{ height: 4, background: theme.s2, borderRadius: 2 }}>
            <div style={{ width: `${(m.amt / maxMat) * 100}%`, height: '100%', background: m.barColor, borderRadius: 2 }} />
          </div>
          {expandedMat === i && (
            <div style={{ marginTop: 10, background: theme.expBg, borderRadius: 8, overflow: 'hidden' }}>
              <table style={{ width: '100%', borderCollapse: 'collapse' }}>
                <thead><tr>{['DATE','VENDOR','QTY','RATE','TOTAL'].map(h => <th key={h} style={th}>{h}</th>)}</tr></thead>
                <tbody>
                  {m.purchases.map((p, j) => (
                    <tr key={j}>
                      <td style={td}>{p.date}</td>
                      <td style={td}>{p.vendor}</td>
                      <td style={td}>{p.qty} {p.unit}</td>
                      <td style={td}>{p.rate}</td>
                      <td style={{ ...td, color: '#007aff' }}>{fmtF(p.total)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      ))}
      <div style={{ textAlign: 'center', fontWeight: 700, color: '#007aff', marginTop: 12, fontSize: 13 }}>
        Net Material {fmtF(data.kpis.materialBilled)}
      </div>
    </div>
  );

  const renderPayments = () => {
    const filtered = payMonth ? monthGroups.filter(([m]) => m === payMonth) : monthGroups;
    return (
      <div style={{ padding: '12px 14px 80px' }}>
        <div style={{ display: 'flex', gap: 8, marginBottom: 12 }}>
          {data.payers.map(p => (
            <div key={p.name} style={{ ...card, flex: 1, textAlign: 'center', padding: 10 }}>
              <div style={{ fontSize: 10, color: theme.txt2 }}>{p.name}</div>
              <div style={{ fontSize: 14, fontWeight: 700, color: p.color, fontVariantNumeric: 'tabular-nums' }}>{fmt(p.amount)}</div>
              <div style={{ fontSize: 9, color: theme.txt3 }}>{p.count} payments</div>
            </div>
          ))}
        </div>
        <div style={{ height: 6, display: 'flex', borderRadius: 3, overflow: 'hidden', marginBottom: 4 }}>
          {data.payers.map(p => (
            <div key={p.name} style={{ width: `${(p.amount / payerTotal) * 100}%`, background: p.color }} />
          ))}
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 12 }}>
          {data.payers.map(p => (
            <span key={p.name} style={{ fontSize: 9, color: p.color }}>{Math.round(p.amount / payerTotal * 100)}%</span>
          ))}
        </div>
        <div style={{ display: 'flex', gap: 8, overflowX: 'auto', marginBottom: 14, paddingBottom: 4 }}>
          <div onClick={() => setPayMonth(null)} style={{ ...card, flexShrink: 0, padding: '8px 12px', cursor: 'pointer', border: !payMonth ? '1px solid #007aff' : undefined }}>
            <div style={{ fontSize: 10 }}>All</div>
          </div>
          {monthGroups.map(([m, g]) => (
            <div key={m} onClick={() => setPayMonth(m)} style={{ ...card, flexShrink: 0, padding: '8px 12px', cursor: 'pointer', border: payMonth === m ? '1px solid #007aff' : undefined }}>
              <div style={{ fontSize: 10, fontWeight: 600 }}>{m}</div>
              <div style={{ fontSize: 11, color: '#ff6b35', fontWeight: 700 }}>{fmt(g.total)}</div>
              <div style={{ fontSize: 9, color: theme.txt3 }}>{g.count} payments</div>
            </div>
          ))}
        </div>
        {filtered.map(([month, g]) => (
          <div key={month}>
            <div style={{ position: 'sticky', top: 0, background: theme.bg, padding: '8px 0', zIndex: 2, display: 'flex', justifyContent: 'space-between', borderBottom: `1px solid ${theme.sep}` }}>
              <span style={{ fontWeight: 700, fontSize: 13 }}>{month}</span>
              <span style={{ fontSize: 11, color: theme.txt2 }}>{fmt(g.total)} · {g.count}</span>
            </div>
            {g.items.map((p, i) => (
              <div key={i} style={{ ...card, marginBottom: 8, display: 'flex', gap: 10, alignItems: 'stretch' }}>
                <div style={{ width: 4, borderRadius: 2, background: p.payerColor, flexShrink: 0 }} />
                <div style={{ flex: 1 }}>
                  <div style={{ fontWeight: 700, fontSize: 13 }}>{p.to}</div>
                  <div style={{ fontSize: 10, color: theme.txt2 }}>{p.desc}</div>
                  <div style={{ fontSize: 9, color: theme.txt3 }}>{p.payer} · {p.mode}</div>
                </div>
                <div style={{ textAlign: 'right' }}>
                  <div style={{ color: '#ff6b35', fontWeight: 700, fontSize: 13 }}>{fmtF(p.amt)}</div>
                  <div style={{ fontSize: 9, color: theme.txt3 }}>{p.date}</div>
                </div>
              </div>
            ))}
          </div>
        ))}
      </div>
    );
  };

  const renderBreakdown = () => (
    <div style={{ padding: '12px 14px 80px' }}>
      <div style={card}>
        <Donut categories={data.categories} total={data.kpis.materialBilled} dark={dark} />
      </div>
      <div style={{ marginTop: 14 }}>
        {data.categories.map((c, i) => (
          <div key={i} style={{ ...card, marginBottom: 8, cursor: 'pointer' }} onClick={() => setExpandedCat(expandedCat === i ? null : i)}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              <span style={{ fontSize: 16 }}>{c.icon}</span>
              <div style={{ flex: 1 }}>
                <div style={{ fontWeight: 600, fontSize: 12 }}>{c.name}</div>
                <div style={{ fontSize: 9, color: theme.txt3 }}>{c.sub}</div>
              </div>
              <span style={{ fontWeight: 700 }}>{fmt(c.amt)}</span>
              <span style={{ fontSize: 10, color: theme.txt2, width: 36, textAlign: 'right' }}>{c.pct}%</span>
              <span style={{ transform: expandedCat === i ? 'rotate(90deg)' : 'none', transition: 'transform .2s', color: theme.txt3 }}>›</span>
            </div>
            {expandedCat === i && (
              <div style={{ marginTop: 10, background: theme.expBg, borderRadius: 8, padding: 8 }}>
                {c.items.map((it, j) => (
                  <div key={j} style={{ marginBottom: 8 }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                      <span style={{ fontSize: 11, fontWeight: 600 }}>{it.name}</span>
                      <span style={{ fontSize: 11, fontWeight: 700, color: c.color }}>{fmt(it.amt)}</span>
                    </div>
                    <div style={{ fontSize: 9, color: theme.txt3 }}>{it.detail}</div>
                    <div style={{ fontSize: 9, color: theme.txt3 }}>{c.amt > 0 ? Math.round(it.amt / c.amt * 100) : 0}% of category</div>
                  </div>
                ))}
              </div>
            )}
          </div>
        ))}
      </div>
    </div>
  );

  const tabContent = [renderOverview, renderVendors, renderMaterials, renderPayments, renderBreakdown][tab]();

  return (
    <div style={{
      '--txt2': theme.txt2,
      maxWidth: 390, margin: '0 auto', minHeight: '100vh', background: theme.bg, color: theme.txt,
      fontFamily: "Inter, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif",
      position: 'relative', overflow: 'hidden'
    }}>
      <div style={{
        background: 'linear-gradient(180deg, #0a0a0a, #1a1a2e 60%, #16213e)',
        padding: '16px 14px 20px', position: 'relative'
      }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
          <div>
            <div style={{ fontSize: 9, letterSpacing: 2, color: 'rgba(255,255,255,0.7)', textTransform: 'uppercase' }}>Bihar Home Build</div>
            <div style={{ display: 'inline-block', marginTop: 6, fontSize: 10, color: '#ff9500', background: 'rgba(255,149,0,0.15)', padding: '2px 8px', borderRadius: 8 }}>
              🏗️ {data.phase} Phase
            </div>
          </div>
          <button onClick={() => setDark(!dark)} style={{
            width: 26, height: 26, borderRadius: 13, border: 'none', background: 'rgba(255,255,255,0.15)',
            color: '#fff', fontSize: 12, cursor: 'pointer'
          }}>{dark ? '☀️' : '🌙'}</button>
        </div>
        <div style={{ fontSize: 22, fontWeight: 700, color: '#fff', marginTop: 10 }}>🏠 Project Dashboard</div>
        <div style={{ fontSize: 11, color: 'rgba(255,255,255,0.7)' }}>Started 7 May 2026 · Live Tracker</div>
        <div style={{ fontSize: 10, color: 'rgba(255,255,255,0.5)', marginTop: 2 }}>Updated: {data.updated}</div>
      </div>
      <div style={{ height: 'calc(100vh - 180px)', overflowY: 'auto' }}>{tabContent}</div>
      <div style={{
        position: 'fixed', bottom: 0, left: '50%', transform: 'translateX(-50%)', width: '100%', maxWidth: 390,
        background: dark ? 'rgba(28,28,30,0.95)' : 'rgba(255,255,255,0.95)', backdropFilter: 'blur(10px)',
        borderTop: `0.5px solid ${theme.sep}`, display: 'flex', padding: '6px 0 10px', zIndex: 100
      }}>
        {TABS.map((t, i) => (
          <button key={i} onClick={() => setTab(i)} style={{
            flex: 1, background: 'none', border: 'none', cursor: 'pointer', padding: '4px 0',
            color: tab === i ? '#007aff' : theme.txt3, fontSize: 9
          }}>
            <div style={{ fontSize: 18 }}>{t.icon}</div>
            <div style={{ fontWeight: tab === i ? 600 : 400 }}>{t.label}</div>
          </button>
        ))}
      </div>
    </div>
  );
}
JSX

output = template.sub('__INITIAL_DATA__', initial_data_js)
File.write(File.join(__dir__, '..', 'home_construction_dashboard.jsx'), output)
puts "Generated home_construction_dashboard.jsx (#{output.bytesize} bytes)"
