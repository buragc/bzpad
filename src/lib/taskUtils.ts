import * as chrono from 'chrono-node';
import type { Quadrant, Task, UrgencyLevel } from '../types';

const URGENT_KEYWORDS = ['asap', 'urgent', 'today', 'deadline', 'due', 'now', 'immediately', 'critical'];
const IMPORTANT_KEYWORDS = ['critical', 'important', 'goal', 'milestone', 'review', 'key', 'priority', 'strategic'];

export function detectQuadrant(text: string): Quadrant {
  const lower = text.toLowerCase();
  const isUrgent = URGENT_KEYWORDS.some(kw => lower.includes(kw));
  const isImportant = IMPORTANT_KEYWORDS.some(kw => lower.includes(kw));

  if (isUrgent && isImportant) return 1;
  if (!isUrgent && isImportant) return 2;
  if (isUrgent && !isImportant) return 3;
  return 4;
}

export function parseDueDate(text: string): Date | null {
  const results = chrono.parse(text);
  if (results.length > 0) {
    return results[0].date();
  }
  return null;
}

export function extractTags(text: string): string[] {
  const tagPattern = /#(\w+)/g;
  const tags: string[] = [];
  let match;
  while ((match = tagPattern.exec(text)) !== null) {
    tags.push(match[1].toLowerCase());
  }

  // Also extract urgency/importance keywords as tags
  const lower = text.toLowerCase();
  [...URGENT_KEYWORDS, ...IMPORTANT_KEYWORDS].forEach(kw => {
    if (lower.includes(kw) && !tags.includes(kw)) {
      tags.push(kw);
    }
  });

  return [...new Set(tags)];
}

export function getUrgencyLevel(task: Task): UrgencyLevel {
  if (!task.dueDate) return 'normal';
  const due = new Date(task.dueDate);
  const now = new Date();
  const diffMs = due.getTime() - now.getTime();
  const diffHours = diffMs / (1000 * 60 * 60);
  const diffDays = diffHours / 24;

  if (diffMs < 0) return 'overdue';
  if (diffHours < 24) return 'critical';
  if (diffDays <= 2) return 'warning';
  if (diffDays <= 7) return 'soon';
  return 'normal';
}

export const URGENCY_COLORS: Record<UrgencyLevel, string> = {
  overdue: 'text-red-600 dark:text-red-400',
  critical: 'text-red-500 dark:text-red-400',
  warning: 'text-orange-500 dark:text-orange-400',
  soon: 'text-yellow-600 dark:text-yellow-400',
  normal: 'text-green-600 dark:text-green-400',
};

export const URGENCY_BG: Record<UrgencyLevel, string> = {
  overdue: 'bg-red-100 dark:bg-red-900/30 text-red-700 dark:text-red-300',
  critical: 'bg-red-100 dark:bg-red-900/30 text-red-700 dark:text-red-300',
  warning: 'bg-orange-100 dark:bg-orange-900/30 text-orange-700 dark:text-orange-300',
  soon: 'bg-yellow-100 dark:bg-yellow-900/30 text-yellow-700 dark:text-yellow-300',
  normal: 'bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-300',
};

export function detectHyperlinks(text: string): Array<{ text: string; url?: string }> {
  const urlRegex = /https?:\/\/[^\s]+/g;
  const parts: Array<{ text: string; url?: string }> = [];
  let lastIndex = 0;
  let match;

  while ((match = urlRegex.exec(text)) !== null) {
    if (match.index > lastIndex) {
      parts.push({ text: text.slice(lastIndex, match.index) });
    }
    parts.push({ text: match[0], url: match[0] });
    lastIndex = match.index + match[0].length;
  }

  if (lastIndex < text.length) {
    parts.push({ text: text.slice(lastIndex) });
  }

  return parts.length > 0 ? parts : [{ text }];
}
