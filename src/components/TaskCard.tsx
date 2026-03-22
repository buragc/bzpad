import { useState, useRef, useEffect } from 'react';
import { useSortable } from '@dnd-kit/sortable';
import { CSS } from '@dnd-kit/utilities';
import { format, formatDistanceToNow } from 'date-fns';
import type { Task } from '../types';
import { useTaskStore } from '../store/useTaskStore';
import { getUrgencyLevel, URGENCY_BG, detectHyperlinks } from '../lib/taskUtils';

interface TaskCardProps {
  task: Task;
  isFocused?: boolean;
}

export function TaskCard({ task, isFocused }: TaskCardProps) {
  const {
    selectedIds,
    selectTask,
    completeTask,
    deleteTask,
    updateTask,
    setFocused,
    editingId,
    setEditingId,
  } = useTaskStore();

  const [editValue, setEditValue] = useState(task.title);
  const editRef = useRef<HTMLInputElement>(null);

  const isSelected = selectedIds.has(task.id);
  const isEditing = editingId === task.id;
  const urgency = getUrgencyLevel(task);
  const dueDateStr = task.dueDate ? new Date(task.dueDate) : null;

  const {
    attributes,
    listeners,
    setNodeRef,
    transform,
    transition,
    isDragging,
  } = useSortable({ id: task.id, data: { task } });

  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
  };

  useEffect(() => {
    if (isEditing) {
      setEditValue(task.title);
      editRef.current?.focus();
      editRef.current?.select();
    }
  }, [isEditing, task.title]);

  function handleClick(e: React.MouseEvent) {
    if (isEditing) return;
    if (e.metaKey || e.ctrlKey) {
      selectTask(task.id, 'toggle');
    } else if (e.shiftKey) {
      selectTask(task.id, 'range');
    } else {
      selectTask(task.id, 'single');
      setFocused(task.id);
    }
  }

  function handleDoubleClick() {
    setEditingId(task.id);
  }

  function handleEditSave() {
    const trimmed = editValue.trim();
    if (trimmed && trimmed !== task.title) {
      updateTask(task.id, { title: trimmed });
    }
    setEditingId(null);
  }

  function handleEditKeyDown(e: React.KeyboardEvent) {
    if (e.key === 'Enter') handleEditSave();
    if (e.key === 'Escape') {
      setEditValue(task.title);
      setEditingId(null);
    }
  }

  function handleComplete(e: React.MouseEvent) {
    e.stopPropagation();
    completeTask(task.id);
  }

  function handleDelete(e: React.MouseEvent) {
    e.stopPropagation();
    deleteTask(task.id);
  }

  const cardClasses = [
    'group relative rounded-lg border px-3 py-2 text-sm cursor-pointer select-none transition-all duration-100',
    'bg-white dark:bg-gray-800',
    isDragging
      ? 'opacity-40 scale-95 shadow-xl border-blue-400'
      : isSelected
      ? 'border-blue-400 dark:border-blue-500 bg-blue-50 dark:bg-blue-950/30 shadow-sm'
      : isFocused
      ? 'border-blue-300 dark:border-blue-600 ring-2 ring-blue-400 ring-offset-1 dark:ring-offset-gray-900'
      : 'border-gray-200 dark:border-gray-700 hover:border-gray-300 dark:hover:border-gray-600 hover:shadow-sm',
  ].join(' ');

  const linkParts = detectHyperlinks(task.title);

  return (
    <div
      ref={setNodeRef}
      style={style}
      className={cardClasses}
      onClick={handleClick}
      onDoubleClick={handleDoubleClick}
      onFocus={() => setFocused(task.id)}
      {...attributes}
      tabIndex={0}
      role="listitem"
      aria-selected={isSelected}
      aria-label={task.title}
    >
      {/* Drag handle */}
      <div
        {...listeners}
        className="absolute left-1 top-1/2 -translate-y-1/2 opacity-0 group-hover:opacity-40 cursor-grab active:cursor-grabbing p-1 rounded"
        onClick={e => e.stopPropagation()}
      >
        <svg className="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
          <path d="M7 2a2 2 0 1 0 .001 4.001A2 2 0 0 0 7 2zm0 6a2 2 0 1 0 .001 4.001A2 2 0 0 0 7 8zm0 6a2 2 0 1 0 .001 4.001A2 2 0 0 0 7 14zm6-8a2 2 0 1 0-.001-4.001A2 2 0 0 0 13 6zm0 2a2 2 0 1 0 .001 4.001A2 2 0 0 0 13 8zm0 6a2 2 0 1 0 .001 4.001A2 2 0 0 0 13 14z" />
        </svg>
      </div>

      <div className="flex items-start gap-2 pl-3">
        {/* Complete checkbox */}
        <button
          onClick={handleComplete}
          className="mt-0.5 shrink-0 w-4 h-4 rounded border border-gray-300 dark:border-gray-600 hover:border-green-500 dark:hover:border-green-400 hover:bg-green-50 dark:hover:bg-green-900/20 flex items-center justify-center transition-colors"
          aria-label="Mark complete"
        >
          {task.completedAt && (
            <svg className="w-3 h-3 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={3} d="M5 13l4 4L19 7" />
            </svg>
          )}
        </button>

        {/* Content */}
        <div className="flex-1 min-w-0">
          {isEditing ? (
            <input
              ref={editRef}
              value={editValue}
              onChange={e => setEditValue(e.target.value)}
              onKeyDown={handleEditKeyDown}
              onBlur={handleEditSave}
              onClick={e => e.stopPropagation()}
              className="w-full bg-transparent text-gray-900 dark:text-gray-100 outline-none text-sm"
            />
          ) : (
            <div className="text-gray-900 dark:text-gray-100 leading-snug break-words">
              {linkParts.map((part, i) =>
                part.url ? (
                  <a
                    key={i}
                    href={part.url}
                    target="_blank"
                    rel="noopener noreferrer"
                    onClick={e => e.stopPropagation()}
                    className="text-blue-600 dark:text-blue-400 underline hover:text-blue-800 dark:hover:text-blue-300"
                  >
                    {part.text}
                  </a>
                ) : (
                  <span key={i}>{part.text}</span>
                )
              )}
            </div>
          )}

          {/* Tags */}
          {task.tags.length > 0 && (
            <div className="flex flex-wrap gap-1 mt-1">
              {task.tags.map(tag => (
                <span key={tag} className="text-xs px-1.5 py-0.5 rounded-full bg-gray-100 dark:bg-gray-700 text-gray-500 dark:text-gray-400">
                  #{tag}
                </span>
              ))}
            </div>
          )}

          {/* Due date */}
          {dueDateStr && (
            <div className={`mt-1 text-xs inline-flex items-center gap-1 px-1.5 py-0.5 rounded-full ${URGENCY_BG[urgency]}`}>
              <svg className="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
              </svg>
              {urgency === 'overdue' ? (
                <span>Overdue · {format(dueDateStr, 'MMM d')}</span>
              ) : (
                <span>{formatDistanceToNow(dueDateStr, { addSuffix: true })}</span>
              )}
            </div>
          )}
        </div>

        {/* Delete button */}
        <button
          onClick={handleDelete}
          className="shrink-0 opacity-0 group-hover:opacity-60 hover:!opacity-100 text-gray-400 hover:text-red-500 dark:hover:text-red-400 transition-all p-0.5 rounded"
          aria-label="Delete task"
        >
          <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>
    </div>
  );
}
