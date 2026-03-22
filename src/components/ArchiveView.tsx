import { format } from 'date-fns';
import { useTaskStore } from '../store/useTaskStore';

export function ArchiveView() {
  const { getArchivedTasks, restoreTask, deleteTasks } = useTaskStore();
  const archived = getArchivedTasks();

  return (
    <div className="flex flex-col h-full">
      <div className="px-6 py-4 border-b border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-900">
        <h2 className="text-lg font-semibold text-gray-900 dark:text-gray-100">Archive</h2>
        <p className="text-sm text-gray-500 dark:text-gray-400">{archived.length} completed task{archived.length !== 1 ? 's' : ''}</p>
      </div>

      <div className="flex-1 overflow-y-auto p-6">
        {archived.length === 0 ? (
          <div className="flex flex-col items-center justify-center h-full text-gray-400 dark:text-gray-600 gap-3">
            <svg className="w-16 h-16 opacity-30" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1} d="M5 8h14M5 8a2 2 0 110-4h14a2 2 0 110 4M5 8v10a2 2 0 002 2h10a2 2 0 002-2V8m-9 4h4" />
            </svg>
            <p className="text-sm">No archived tasks yet</p>
          </div>
        ) : (
          <div className="space-y-2 max-w-2xl mx-auto">
            {archived
              .slice()
              .sort((a, b) => new Date(b.completedAt ?? b.createdAt).getTime() - new Date(a.completedAt ?? a.createdAt).getTime())
              .map(task => (
                <div
                  key={task.id}
                  className="flex items-center gap-3 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg px-4 py-3 group"
                >
                  <svg className="w-4 h-4 text-green-500 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M5 13l4 4L19 7" />
                  </svg>
                  <div className="flex-1 min-w-0">
                    <div className="text-sm text-gray-500 dark:text-gray-400 line-through truncate">{task.title}</div>
                    {task.completedAt && (
                      <div className="text-xs text-gray-400 dark:text-gray-500 mt-0.5">
                        Completed {format(new Date(task.completedAt), 'MMM d, yyyy')}
                      </div>
                    )}
                  </div>
                  <div className="flex items-center gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
                    <button
                      onClick={() => restoreTask(task.id)}
                      className="text-xs text-blue-600 dark:text-blue-400 hover:underline"
                    >
                      Restore
                    </button>
                    <button
                      onClick={() => deleteTasks([task.id])}
                      className="text-xs text-red-500 dark:text-red-400 hover:underline"
                    >
                      Delete
                    </button>
                  </div>
                </div>
              ))}
          </div>
        )}
      </div>
    </div>
  );
}
