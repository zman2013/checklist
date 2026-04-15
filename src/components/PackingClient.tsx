'use client';

import { useState, useEffect, useRef } from 'react';
import { useRouter } from 'next/navigation';
import { motion, AnimatePresence } from 'framer-motion';
import CelebrationOverlay from './CelebrationOverlay';
import Toast from './Toast';
import CheckItem from './CheckItem';
import { departTrip } from '@/actions/trips';

interface TripItem {
  id: number;
  text: string;
  checked: boolean;
  forgotCount?: number;
}

interface CategoryGroup {
  category: string;
  items: TripItem[];
}

interface PackingClientProps {
  tripId: number;
  tripName: string;
  destination: string | null;
  status: string;
  groups: CategoryGroup[];
  forgottenGroup: TripItem[];   // "以往忘带" items (from forgotten_items)
  totalCount: number;
  checkedCount: number;
}

export default function PackingClient({
  tripId,
  tripName: _tripName,
  destination: _destination,
  status,
  groups,
  forgottenGroup,
  totalCount,
  checkedCount: initialChecked,
}: PackingClientProps) {
  const router = useRouter();
  const [checkedCount, setCheckedCount] = useState(initialChecked);
  const [celebrating, setCelebrating] = useState(false);
  const [departed, setDeparted] = useState(status === 'departed');
  const [toast, setToast] = useState<string | null>(null);
  const [showDepartCta, setShowDepartCta] = useState(false);

  // Ref guard: prevents celebration from firing more than once per mount.
  // useRef value survives React Strict Mode's double-invoke but is reset on unmount,
  // which is the desired behavior.
  const hasCelebrated = useRef(false);

  const pct = totalCount > 0 ? Math.round((checkedCount / totalCount) * 100) : 0;
  const isComplete = totalCount > 0 && checkedCount >= totalCount;

  // Show celebration when all items are checked for the first time.
  //
  // Why no cleanup return:
  // React Strict Mode (dev) runs effects twice: setup → cleanup → setup.
  // If we returned clearTimeout here, Strict Mode would cancel the timer in the
  // first cleanup pass. `celebrating` would be stuck as `true` forever because
  // `setCelebrating(false)` would never fire.
  //
  // The `hasCelebrated` ref prevents double-fire: Strict Mode's second run sees
  // `hasCelebrated.current = true` and exits early. The timer from the first run
  // fires normally after 2300ms.
  useEffect(() => {
    if (isComplete && !departed && !hasCelebrated.current) {
      hasCelebrated.current = true;
      setCelebrating(true);
      setTimeout(() => {
        setDeparted(true);
        setShowDepartCta(true);
        setCelebrating(false);
        departTrip(tripId);
      }, 2300);
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isComplete, departed, tripId]);

  // Sync checkedCount when Server Component re-renders
  useEffect(() => {
    setCheckedCount(initialChecked);
  }, [initialChecked]);

  // Show/hide depart CTA if already departed
  useEffect(() => {
    if (departed || (status === 'departed')) setShowDepartCta(true);
  }, [departed, status]);

  function showToast(msg: string) {
    setToast(msg);
    setTimeout(() => setToast(null), 3000);
  }

  return (
    <>
      {/* Progress bar */}
      <div
        className="progress-bar-track"
        role="progressbar"
        aria-valuenow={checkedCount}
        aria-valuemax={totalCount}
        aria-label="打包进度"
      >
        <div
          className="progress-bar-fill"
          style={{ width: `${pct}%` }}
        />
      </div>

      {/* Empty state */}
      {groups.length === 0 && forgottenGroup.length === 0 && (
        <div style={{ padding: '32px 16px', textAlign: 'center', color: '#999' }}>
          <p style={{ marginBottom: 8 }}>这个模板还没有条目</p>
          <a
            href={`/templates/${tripId}/edit`}
            style={{ color: '#1a1a1a', fontSize: 13, textDecoration: 'underline' }}
          >
            去编辑模板添加 →
          </a>
        </div>
      )}

      {/* 以往忘带 group */}
      {forgottenGroup.length > 0 && (
        <section>
          <div className="section-label" style={{ background: '#fffbf0' }}>
            以往忘带
          </div>
          {forgottenGroup.map((item) => (
            <div key={`forgotten-${item.id}`} style={{ background: '#fffbf0' }}>
              <CheckItem
                id={item.id}
                text={item.text}
                checked={item.checked}
                forgotCount={item.forgotCount}
              />
            </div>
          ))}
        </section>
      )}

      {/* Template item groups */}
      {groups.map((group) => (
        <section key={group.category}>
          <div className="section-label">{group.category}</div>
          {group.items.map((item) => (
            <CheckItem
              key={item.id}
              id={item.id}
              text={item.text}
              checked={item.checked}
            />
          ))}
        </section>
      ))}

      {/* Celebration overlay */}
      <CelebrationOverlay visible={celebrating} />

      {/* Depart CTA — slide up after celebration */}
      <AnimatePresence>
        {(showDepartCta || departed) && (
          <motion.div
            initial={{ y: 60, opacity: 0 }}
            animate={{ y: 0, opacity: 1 }}
            exit={{ y: 60, opacity: 0 }}
            transition={{ type: 'spring', stiffness: 300, damping: 30 }}
            style={{
              position: 'fixed',
              bottom: 24,
              left: '50%',
              transform: 'translateX(-50%)',
              width: 'min(calc(100% - 32px), 388px)',
              zIndex: 100,
            }}
          >
            <button
              className="btn-primary"
              onClick={() => router.push(`/trips/${tripId}/debrief`)}
            >
              行程结束，记录复盘 →
            </button>
          </motion.div>
        )}
      </AnimatePresence>

      <Toast message={toast} />
    </>
  );
}
