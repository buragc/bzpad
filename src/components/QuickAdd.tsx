import { useState, useRef, useEffect } from 'react';
import { useTaskStore } from '../store/useTaskStore';
import type { Quadrant } from '../types';
import { parseDueDate } from '../lib/taskUtils';

interface QuickAddProps {
  defaultQuadrant?: Quadrant;
  onDone?: () => void;
  autoFocus?: boolean;
  placeholder?: string;
}

export function QuickAdd({ defaultQuadrant, onDone, autoFocus, placeholder }: QuickAddProps) {
  const [value, setValue] = useState('');
  const [parsedDate, setParsedDate] = useState<Date | null>(null);
  const inputRef = useRef<HTMLInputElement>(null);
  const addTask = useTaskStore(s => s.addTask);

  useEffect(() => {
    if (autoFocus) inputRef.current?.focus();
  }, [autoFocus]);

  function handleChange(e: React.ChangeEvent<HTMLInputElement>) {
    const text = e.target.value;
    setValue(text);
    setParsedDate(parseDueDate(text));
  }

  function handleSubmit(e?: React.FormEvent) {
    e?.preventDefault();
    const trimmed = value.trim();
    if (!trimmed) return;
    addTask(trimmed, defaultQuadrant);
    setValue('');
    setParsedDate(null);
    onDone?.();
  }

  function handleKeyDown(e: React.KeyboardEvent) {
    if (e.key === 'Escape') {
      setValue('');
      setParsedDate(null);
      onDone?.();
    }
  }

  return (
    <form onSubmit={handleSubmit} className="relative">
      <div className="flex items-center gap-2 px-3 py-2 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg shadow-sm focus-within:border-blue-400 dark:focus-within:border-blue-500 focus-within:ring-1 focus-within:ring-blue-400 dark:focus-within:ring-blue-500 transition-all">
        <svg className="w-4 h-4 text-gray-400 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
        </svg>
        <input
          ref={inputRef}
          type="text"
          value={value}
          onChange={handleChange}
          onKeyDown={handleKeyDown}
          placeholder={placeholder ?? 'Add task… (supports "due tomorrow", "urgent", #tags)'}
          className="flex-1 bg-transparent text-sm text-gray-900 dark:text-gray-100 placeholder-gray-400 outline-none min-w-0"
        />
        {parsedDate && (
          <span className="text-xs text-blue-600 dark:text-blue-400 shrink-0 bg-blue-50 dark:bg-blue-950/40 px-2 py-0.5 rounded-full">
            {parsedDate.toLocaleDateString(undefined, { month: 'short', day: 'numeric' })}
          </span>
        )}
        {value.trim() && (
          <button
            type="submit"
            className="shrink-0 text-xs bg-blue-600 hover:bg-blue-700 text-white px-2.5 py-1 rounded-md transition-colors"
          >
            Add
          </button>
        )}
      </div>
    </form>
  );
}
