'use client';

import { motion, AnimatePresence } from 'framer-motion';
import { useState } from 'react';
import { toggleItem } from '@/actions/trips';

interface CheckItemProps {
  id: number;
  text: string;
  checked: boolean;
  forgotCount?: number;  // times_forgotten from forgotten_items, if any
}

export default function CheckItem({ id, text, checked: initialChecked, forgotCount }: CheckItemProps) {
  const [checked, setChecked] = useState(initialChecked);
  const [shaking, setShaking] = useState(false);

  async function handleToggle() {
    const next = !checked;
    setChecked(next); // optimistic

    const result = await toggleItem(id, next);
    if (!result.ok) {
      setChecked(!next); // revert
      setShaking(true);
      setTimeout(() => setShaking(false), 400);
    }
  }

  return (
    <motion.label
      className="item-row"
      style={{ cursor: 'pointer' }}
      animate={
        shaking
          ? { x: [0, -4, 4, -4, 0] }
          : { x: 0 }
      }
      transition={{ duration: 0.3 }}
    >
      {/* Hidden native checkbox for a11y */}
      <input
        type="checkbox"
        checked={checked}
        onChange={handleToggle}
        className="sr-only"
        aria-label={text}
      />

      {/* Visual checkbox */}
      <motion.div
        className={`check-box ${checked ? 'checked' : ''}`}
        onClick={handleToggle}
        aria-hidden="true"
      >
        <AnimatePresence>
          {checked && (
            <motion.svg
              key="check"
              width="12"
              height="9"
              viewBox="0 0 12 9"
              fill="none"
              initial={{ scale: 0, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0, opacity: 0 }}
              transition={{ duration: 0.15, ease: 'easeOut' }}
            >
              <path
                d="M1 4L4.5 7.5L11 1"
                stroke="white"
                strokeWidth="1.8"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
            </motion.svg>
          )}
        </AnimatePresence>
      </motion.div>

      {/* Item text */}
      <motion.span
        className={`item-text ${checked ? 'done' : ''}`}
        animate={{
          color: checked ? '#c0c0c0' : '#1a1a1a',
        }}
        transition={{ duration: 0.2 }}
      >
        {text}
      </motion.span>

      {/* Forgot badge */}
      {forgotCount && forgotCount > 0 && !checked && (
        <span className="forgot-badge">
          forgot {forgotCount}×
        </span>
      )}
    </motion.label>
  );
}
