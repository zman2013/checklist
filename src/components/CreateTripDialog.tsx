'use client';

import { useState, useRef, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { motion } from 'framer-motion';
import { createTrip } from '@/actions/trips';

interface CreateTripDialogProps {
  templateId: number;
  templateName: string;
  onClose: () => void;
}

export default function CreateTripDialog({
  templateId,
  templateName,
  onClose,
}: CreateTripDialogProps) {
  const router = useRouter();
  const [destination, setDestination] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    inputRef.current?.focus();
  }, []);

  // Close on Escape
  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if (e.key === 'Escape') onClose();
    }
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [onClose]);

  async function handleStart() {
    setLoading(true);
    setError('');
    const result = await createTrip(templateId, destination.trim() || undefined);
    if (!result.ok) {
      setError(result.error);
      setLoading(false);
      return;
    }
    router.push(`/trips/${result.data.tripId}`);
  }

  return (
    <div
      style={{
        position: 'fixed',
        inset: 0,
        background: 'rgba(26,26,26,0.5)',
        display: 'flex',
        alignItems: 'flex-end',
        justifyContent: 'center',
        zIndex: 500,
        padding: '0 0 0 0',
      }}
      onClick={(e) => { if (e.target === e.currentTarget) onClose(); }}
      role="dialog"
      aria-modal="true"
      aria-label={`开始${templateName}行程`}
    >
      <motion.div
        initial={{ y: '100%' }}
        animate={{ y: 0 }}
        exit={{ y: '100%' }}
        transition={{ type: 'spring', stiffness: 400, damping: 35 }}
        style={{
          width: 'min(100%, 420px)',
          background: '#fafafa',
          borderRadius: '12px 12px 0 0',
          padding: '24px 16px 32px',
        }}
      >
        <div style={{ marginBottom: 20 }}>
          <p className="page-title" style={{ fontSize: 16, marginBottom: 4 }}>
            {templateName}
          </p>
          <p className="helper-text">目的地（可选）</p>
        </div>

        <input
          ref={inputRef}
          className="input-field"
          placeholder="例如：上海、东京、成都..."
          value={destination}
          onChange={(e) => setDestination(e.target.value)}
          onKeyDown={(e) => { if (e.key === 'Enter') handleStart(); }}
          style={{ marginBottom: 12 }}
        />

        {error && (
          <p style={{ color: 'var(--danger)', fontSize: 13, marginBottom: 8 }}>
            {error}
          </p>
        )}

        <button
          className="btn-primary"
          onClick={handleStart}
          disabled={loading}
          style={{ marginBottom: 8 }}
        >
          {loading ? '准备中...' : '开始打包 →'}
        </button>

        <button className="btn-text" onClick={onClose} style={{ display: 'block', margin: '0 auto' }}>
          取消
        </button>
      </motion.div>
    </div>
  );
}
