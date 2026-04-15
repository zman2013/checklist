// Debrief page — Server Component + Client form
'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { submitDebrief } from '@/actions/debrief';

interface DebriefFormProps {
  tripId: number;
  tripName: string;
}

export default function DebriefForm({ tripId, tripName }: DebriefFormProps) {
  const router = useRouter();
  const [forgotten, setForgotten] = useState('');
  const [surplus, setSurplus] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  async function handleSubmit() {
    setLoading(true);
    setError('');

    const forgottenList = forgotten
      .split('\n')
      .map((s) => s.trim())
      .filter(Boolean);
    const surplusList = surplus
      .split('\n')
      .map((s) => s.trim())
      .filter(Boolean);

    const result = await submitDebrief(tripId, forgottenList, surplusList);
    if (!result.ok) {
      setError(result.error);
      setLoading(false);
      return;
    }
    router.push('/');
  }

  async function handleSkip() {
    setLoading(true);
    await submitDebrief(tripId, [], []);
    router.push('/');
  }

  return (
    <main style={{ padding: '32px 16px 32px' }}>
      {/* Header */}
      <h1
        className="page-title"
        style={{ textAlign: 'center', marginBottom: 6 }}
      >
        这次怎么样？
      </h1>
      <p
        style={{
          textAlign: 'center',
          fontSize: 13,
          color: '#999',
          marginBottom: 32,
        }}
      >
        {tripName}
      </p>

      {/* Forgotten field */}
      <div style={{ marginBottom: 20 }}>
        <label
          htmlFor="forgotten"
          className="section-label"
          style={{ display: 'block', padding: '0 0 8px' }}
        >
          忘带了什么？
        </label>
        <p className="helper-text" style={{ marginBottom: 8 }}>
          每行一条，下次出行时会有提醒
        </p>
        <textarea
          id="forgotten"
          className="textarea-field"
          placeholder={"充电宝\n雨伞\n..."}
          value={forgotten}
          onChange={(e) => setForgotten(e.target.value)}
          rows={4}
        />
      </div>

      {/* Surplus field */}
      <div style={{ marginBottom: 28 }}>
        <label
          htmlFor="surplus"
          className="section-label"
          style={{ display: 'block', padding: '0 0 8px' }}
        >
          带多了什么？（可选）
        </label>
        <textarea
          id="surplus"
          className="textarea-field"
          placeholder={"备用西装\n厚外套\n..."}
          value={surplus}
          onChange={(e) => setSurplus(e.target.value)}
          rows={3}
        />
      </div>

      {error && (
        <p
          style={{
            color: 'var(--danger)',
            fontSize: 13,
            marginBottom: 12,
            textAlign: 'center',
          }}
        >
          {error}
        </p>
      )}

      <button
        className="btn-primary"
        onClick={handleSubmit}
        disabled={loading}
        style={{ marginBottom: 12 }}
      >
        {loading ? '保存中...' : '保存并结束行程'}
      </button>

      <div style={{ textAlign: 'center' }}>
        <button className="btn-text" onClick={handleSkip} disabled={loading}>
          跳过，直接结束
        </button>
      </div>
    </main>
  );
}
