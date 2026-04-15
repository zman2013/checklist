'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { createTemplate } from '@/actions/templates';

const EMOJI_PRESETS = ['🧳', '💼', '🏖️', '🏕️', '🥾', '⛷️', '🚗', '✈️', '🎒', '🏔️', '🚢', '🌏'];

export default function NewTemplatePage() {
  const router = useRouter();
  const [name, setName] = useState('');
  const [icon, setIcon] = useState('🧳');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  async function handleCreate() {
    if (!name.trim()) {
      setError('请填写行程类型名称');
      return;
    }
    setLoading(true);
    setError('');
    const result = await createTemplate(name.trim(), icon);
    if (!result.ok) {
      setError(result.error);
      setLoading(false);
      return;
    }
    router.push(`/templates/${result.data.templateId}/edit`);
  }

  return (
    <main style={{ padding: '16px' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 24 }}>
        <button
          onClick={() => router.back()}
          style={{
            background: 'none',
            border: 'none',
            color: '#999',
            fontSize: 20,
            cursor: 'pointer',
            padding: 0,
          }}
          aria-label="返回"
        >
          ←
        </button>
        <h1 className="page-title" style={{ margin: 0 }}>新建行程类型</h1>
      </div>

      <div style={{ marginBottom: 20 }}>
        <label htmlFor="tname" className="section-label" style={{ display: 'block', padding: '0 0 8px' }}>
          名称
        </label>
        <input
          id="tname"
          className="input-field"
          placeholder="例如：滑雪、商务出行..."
          value={name}
          onChange={(e) => setName(e.target.value)}
          onKeyDown={(e) => { if (e.key === 'Enter') handleCreate(); }}
          autoFocus
        />
      </div>

      <div style={{ marginBottom: 28 }}>
        <div className="section-label" style={{ padding: '0 0 12px' }}>图标</div>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
          {EMOJI_PRESETS.map((emoji) => (
            <button
              key={emoji}
              onClick={() => setIcon(emoji)}
              style={{
                width: 44,
                height: 44,
                fontSize: 24,
                border: icon === emoji ? '2px solid #1a1a1a' : '1px solid var(--border)',
                borderRadius: 6,
                background: icon === emoji ? '#f5f5f5' : 'white',
                cursor: 'pointer',
              }}
              aria-label={emoji}
              aria-pressed={icon === emoji}
            >
              {emoji}
            </button>
          ))}
        </div>
      </div>

      {error && (
        <p style={{ color: 'var(--danger)', fontSize: 13, marginBottom: 12 }}>{error}</p>
      )}

      <button className="btn-primary" onClick={handleCreate} disabled={loading}>
        {loading ? '创建中...' : '创建并添加条目 →'}
      </button>
    </main>
  );
}
