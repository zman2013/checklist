'use client';

import { motion, AnimatePresence } from 'framer-motion';

interface CelebrationOverlayProps {
  visible: boolean;
}

export default function CelebrationOverlay({ visible }: CelebrationOverlayProps) {
  return (
    <AnimatePresence>
      {visible && (
        <motion.div
          className="celebration-overlay"
          initial={{ opacity: 0 }}
          animate={{ opacity: 0.92 }}
          exit={{ opacity: 0 }}
          transition={{ duration: 0.3, ease: 'easeOut' }}
          aria-live="polite"
          aria-atomic="true"
        >
          <motion.span
            className="celebration-text"
            initial={{ scale: 0.8, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            exit={{ scale: 0.8, opacity: 0 }}
            transition={{
              type: 'spring',
              stiffness: 300,
              damping: 25,
              duration: 0.4,
            }}
          >
            出发吧！
          </motion.span>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
