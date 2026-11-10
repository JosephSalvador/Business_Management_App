import React from 'react';
import {
  CheckCircle2,
  AlertTriangle,
  XCircle,
  Info,
  Clock,
  ChevronRight,
  X,
  RefreshCw,
} from 'lucide-react';

export function Button({
  children,
  variant = 'normal', // 'primary' | 'normal' | 'danger' | 'link' | 'ghost'
  size = 'md', // 'sm' | 'md'
  icon: Icon,
  loading = false,
  disabled = false,
  onClick,
  type = 'button',
  className = '',
  title,
}) {
  const base =
    'inline-flex items-center justify-center font-semibold transition-colors rounded-[4px] select-none focus:outline-none focus:ring-2 focus:ring-[#0972D3] focus:ring-offset-1 disabled:opacity-50 disabled:cursor-not-allowed';

  const sizes = {
    sm: 'px-2.5 py-1 text-[12px] leading-[16px] gap-1.5',
    md: 'px-3.5 py-1.5 text-[13px] leading-[18px] gap-1.5',
  };

  const variants = {
    primary:
      'bg-[#0972D3] hover:bg-[#033160] text-white border border-[#0972D3] hover:border-[#033160]',
    normal:
      'bg-white hover:bg-[#F2F3F3] text-[#16191F] border border-[#879596]',
    danger:
      'bg-white hover:bg-[#FDF3F1] text-[#D91515] border border-[#D91515]',
    dangerPrimary:
      'bg-[#D91515] hover:bg-[#A81111] text-white border border-[#D91515]',
    link: 'bg-transparent hover:underline text-[#0972D3] px-1 py-0.5 border-0 font-medium',
    ghost:
      'bg-transparent hover:bg-[#F2F3F3] text-[#5F6B7A] hover:text-[#16191F] border border-transparent',
  };

  return (
    <button
      type={type}
      disabled={disabled || loading}
      onClick={onClick}
      title={title}
      className={`${base} ${sizes[size] || sizes.md} ${variants[variant] || variants.normal} ${className}`}
    >
      {loading ? (
        <RefreshCw className="w-3.5 h-3.5 animate-spin shrink-0" />
      ) : Icon ? (
        <Icon className="w-3.5 h-3.5 shrink-0" />
      ) : null}
      {children && <span>{children}</span>}
    </button>
  );
}

export function Container({
  title,
  count,
  description,
  actions,
  footer,
  noPadding = false,
  className = '',
  children,
}) {
  return (
    <div
      className={`bg-white border border-[#D5DBDB] rounded-[8px] shadow-sm overflow-hidden ${className}`}
    >
      {(title || actions || description) && (
        <div className="px-5 py-3.5 border-b border-[#E9EBED] bg-[#FAFAFA] flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2">
          <div>
            {title && (
              <div className="flex items-center gap-1.5">
                <h2 className="text-[16px] font-bold text-[#16191F] leading-[22px]">
                  {title}
                </h2>
                {count !== undefined && count !== null && (
                  <span className="text-[14px] font-normal text-[#5F6B7A]">
                    ({count})
                  </span>
                )}
              </div>
            )}
            {description && (
              <p className="text-[12px] text-[#5F6B7A] mt-0.5">{description}</p>
            )}
          </div>
          {actions && (
            <div className="flex items-center flex-wrap gap-2 shrink-0">
              {actions}
            </div>
          )}
        </div>
      )}
      <div className={noPadding ? '' : 'p-5'}>{children}</div>
      {footer && (
        <div className="px-5 py-3 border-t border-[#E9EBED] bg-[#FAFAFA]">
          {footer}
        </div>
      )}
    </div>
  );
}

export function PageHeader({
  title,
  count,
  subtitle,
  badge,
  actions,
}) {
  return (
    <div className="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-3 pb-4">
      <div>
        <div className="flex items-center flex-wrap gap-2.5">
          <h1 className="text-[22px] font-bold text-[#16191F] tracking-tight leading-[28px]">
            {title}
            {count !== undefined && count !== null && (
              <span className="ml-1.5 text-[18px] font-normal text-[#5F6B7A]">
                ({count})
              </span>
            )}
          </h1>
          {badge}
        </div>
        {subtitle && (
          <p className="text-[13px] text-[#5F6B7A] mt-1 max-w-3xl">{subtitle}</p>
        )}
      </div>
      {actions && (
        <div className="flex items-center flex-wrap gap-2 shrink-0">
          {actions}
        </div>
      )}
    </div>
  );
}

export function Breadcrumbs({ items = [] }) {
  if (!items.length) return null;
  return (
    <nav aria-label="Breadcrumb" className="mb-2">
      <ol className="flex items-center flex-wrap gap-1 text-[12px] text-[#5F6B7A]">
        {items.map((item, idx) => {
          const isLast = idx === items.length - 1;
          return (
            <li key={idx} className="flex items-center gap-1">
              {idx > 0 && <ChevronRight className="w-3.5 h-3.5 text-[#879596]" />}
              {isLast || !item.onClick ? (
                <span
                  className={
                    isLast
                      ? 'font-semibold text-[#16191F]'
                      : 'text-[#5F6B7A]'
                  }
                >
                  {item.label}
                </span>
              ) : (
                <button
                  type="button"
                  onClick={item.onClick}
                  className="text-[#0972D3] hover:underline font-medium"
                >
                  {item.label}
                </button>
              )}
            </li>
          );
        })}
      </ol>
    </nav>
  );
}

export function StatusIndicator({ type = 'info', children }) {
  // type: 'success' | 'warning' | 'error' | 'info' | 'pending' | 'stopped'
  const config = {
    success: {
      icon: CheckCircle2,
      text: 'text-[#037F0C]',
      bg: 'bg-[#F2FAF3]',
      border: 'border-[#A6E0AE]',
    },
    warning: {
      icon: AlertTriangle,
      text: 'text-[#8D6605]',
      bg: 'bg-[#FFF4CC]',
      border: 'border-[#E0CA5C]',
    },
    error: {
      icon: XCircle,
      text: 'text-[#D91515]',
      bg: 'bg-[#FDF3F1]',
      border: 'border-[#F5B5AD]',
    },
    info: {
      icon: Info,
      text: 'text-[#0972D3]',
      bg: 'bg-[#F1F8FF]',
      border: 'border-[#99CBE4]',
    },
    pending: {
      icon: Clock,
      text: 'text-[#5F6B7A]',
      bg: 'bg-[#F2F3F3]',
      border: 'border-[#D5DBDB]',
    },
  };

  const c = config[type] || config.info;
  const Icon = c.icon;

  return (
    <span
      className={`inline-flex items-center gap-1.5 px-2 py-0.5 rounded-[4px] text-[12px] font-medium border ${c.bg} ${c.text} ${c.border}`}
    >
      <Icon className="w-3.5 h-3.5 shrink-0" />
      <span>{children}</span>
    </span>
  );
}

export function Badge({ children, color = 'neutral' }) {
  // color: 'neutral' | 'blue' | 'green' | 'red' | 'amber'
  const styles = {
    neutral: 'bg-[#F2F3F3] text-[#16191F] border-[#D5DBDB]',
    blue: 'bg-[#F1F8FF] text-[#0972D3] border-[#99CBE4]',
    green: 'bg-[#F2FAF3] text-[#037F0C] border-[#A6E0AE]',
    red: 'bg-[#FDF3F1] text-[#D91515] border-[#F5B5AD]',
    amber: 'bg-[#FFF4CC] text-[#533B04] border-[#E0CA5C]',
  };
  return (
    <span
      className={`inline-flex items-center px-2 py-0.5 rounded-[4px] text-[11px] font-semibold border ${styles[color] || styles.neutral}`}
    >
      {children}
    </span>
  );
}

export function Alert({
  type = 'info', // 'info' | 'success' | 'warning' | 'error'
  title,
  children,
  action,
  onDismiss,
  className = '',
}) {
  const styles = {
    info: {
      icon: Info,
      container: 'bg-[#F1F8FF] border-[#0972D3] text-[#16191F]',
      iconColor: 'text-[#0972D3]',
    },
    success: {
      icon: CheckCircle2,
      container: 'bg-[#F2FAF3] border-[#037F0C] text-[#16191F]',
      iconColor: 'text-[#037F0C]',
    },
    warning: {
      icon: AlertTriangle,
      container: 'bg-[#FFF4CC] border-[#8D6605] text-[#16191F]',
      iconColor: 'text-[#8D6605]',
    },
    error: {
      icon: XCircle,
      container: 'bg-[#FDF3F1] border-[#D91515] text-[#16191F]',
      iconColor: 'text-[#D91515]',
    },
  };

  const s = styles[type] || styles.info;
  const Icon = s.icon;

  return (
    <div
      className={`border-l-4 border rounded-[4px] px-4 py-3 flex items-start justify-between gap-3 ${s.container} ${className}`}
    >
      <div className="flex items-start gap-2.5">
        <Icon className={`w-4 h-4 mt-0.5 shrink-0 ${s.iconColor}`} />
        <div className="text-[13px] leading-[18px]">
          {title && <div className="font-bold mb-0.5">{title}</div>}
          <div>{children}</div>
        </div>
      </div>
      <div className="flex items-center gap-2 shrink-0">
        {action}
        {onDismiss && (
          <button
            type="button"
            onClick={onDismiss}
            className="text-[#5F6B7A] hover:text-[#16191F] p-0.5"
          >
            <X className="w-4 h-4" />
          </button>
        )}
      </div>
    </div>
  );
}

export function Tabs({ tabs = [], activeId, onChange }) {
  return (
    <div className="border-b border-[#D5DBDB] bg-white px-4">
      <nav className="-mb-px flex space-x-6 overflow-x-auto" aria-label="Tabs">
        {tabs.map((tab) => {
          const active = tab.id === activeId;
          const Icon = tab.icon;
          return (
            <button
              key={tab.id}
              type="button"
              onClick={() => onChange(tab.id)}
              className={`whitespace-nowrap py-3 px-1 border-b-2 text-[13px] font-semibold flex items-center gap-1.5 transition-colors ${
                active
                  ? 'border-[#0972D3] text-[#0972D3]'
                  : 'border-transparent text-[#5F6B7A] hover:text-[#16191F] hover:border-[#879596]'
              }`}
            >
              {Icon && <Icon className="w-4 h-4" />}
              <span>{tab.label}</span>
              {tab.count !== undefined && (
                <span
                  className={`ml-1 text-[11px] px-1.5 py-0.2 rounded-[2px] ${
                    active
                      ? 'bg-[#F1F8FF] text-[#0972D3]'
                      : 'bg-[#F2F3F3] text-[#5F6B7A]'
                  }`}
                >
                  {tab.count}
                </span>
              )}
            </button>
          );
        })}
      </nav>
    </div>
  );
}

export function Modal({
  open,
  onClose,
  title,
  footer,
  size = 'md', // 'sm' | 'md' | 'lg'
  children,
}) {
  if (!open) return null;
  const widths = {
    sm: 'max-w-md',
    md: 'max-w-xl',
    lg: 'max-w-3xl',
  };
  return (
    <div className="fixed inset-0 z-50 bg-[#16191F]/50 flex items-center justify-center p-4">
      <div
        className={`bg-white border border-[#D5DBDB] rounded-[8px] shadow-xl w-full ${widths[size] || widths.md} max-h-[90vh] flex flex-col overflow-hidden`}
      >
        <div className="px-5 py-3.5 border-b border-[#E9EBED] bg-[#FAFAFA] flex items-center justify-between">
          <h3 className="text-[16px] font-bold text-[#16191F]">{title}</h3>
          <button
            type="button"
            onClick={onClose}
            className="text-[#5F6B7A] hover:text-[#16191F] p-1 rounded-[4px]"
          >
            <X className="w-4 h-4" />
          </button>
        </div>
        <div className="p-5 overflow-y-auto flex-1">{children}</div>
        {footer && (
          <div className="px-5 py-3 border-t border-[#E9EBED] bg-[#FAFAFA] flex items-center justify-end gap-2">
            {footer}
          </div>
        )}
      </div>
    </div>
  );
}

export function KeyValueGrid({ items = [], columns = 4 }) {
  const colClass =
    columns === 2
      ? 'sm:grid-cols-2'
      : columns === 3
      ? 'sm:grid-cols-3'
      : 'sm:grid-cols-2 lg:grid-cols-4';

  return (
    <div
      className={`grid grid-cols-1 ${colClass} gap-4 divide-y sm:divide-y-0 sm:divide-x divide-[#E9EBED]`}
    >
      {items.map((item, idx) => (
        <div
          key={idx}
          className={idx > 0 ? 'pt-3 sm:pt-0 sm:pl-4' : ''}
        >
          <div className="text-[12px] font-medium text-[#5F6B7A]">
            {item.label}
          </div>
          <div className="mt-1 text-[14px] font-semibold text-[#16191F]">
            {item.value}
          </div>
          {item.sub && (
            <div className="text-[11px] text-[#5F6B7A] mt-0.5">{item.sub}</div>
          )}
        </div>
      ))}
    </div>
  );
}

export function KpiStrip({ metrics = [] }) {
  return (
    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
      {metrics.map((m, idx) => (
        <div
          key={idx}
          className="bg-white border border-[#D5DBDB] rounded-[8px] px-4 py-3.5 shadow-sm"
        >
          <div className="text-[12px] font-medium text-[#5F6B7A]">
            {m.label}
          </div>
          <div className="mt-1 text-[22px] font-bold text-[#16191F] tabular-nums leading-[28px]">
            {m.value}
          </div>
          {m.sub && (
            <div className="mt-1 text-[11px] text-[#5F6B7A]">{m.sub}</div>
          )}
        </div>
      ))}
    </div>
  );
}
