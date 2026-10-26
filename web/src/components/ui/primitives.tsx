'use client';

/**
 * Shared UI Components mirroring the Flutter mobile design system
 * (`docs/web/07-design-responsive.md` & `lib/shared/widgets/`).
 *
 * Components: `AppCard`, `StatTile`, `SectionHeader`, `RangeSelector`,
 * `SegmentedControl`, `SelectableChip`, `StatusPill`, `MetricBadge`,
 * `EmptyState`, `ErrorState`, `LoadingState`.
 */

import React from 'react';
import {
  Activity,
  AlertCircle,
  CheckCircle2,
  Droplet,
  Heart,
  Info,
  Scale,
  Thermometer,
  Wind,
} from 'lucide-react';
import type { AnalysisRangeDays, MetricWireName } from '@/domain';

export type StatusTone = 'positive' | 'warning' | 'critical' | 'primary' | 'neutral';

export function metricAccentVar(metric: MetricWireName): string {
  switch (metric) {
    case 'blood_pressure':
      return 'var(--metric-bp)';
    case 'weight':
      return 'var(--metric-weight)';
    case 'heart_rate':
      return 'var(--metric-hr)';
    case 'spo2':
      return 'var(--metric-spo2)';
    case 'body_temperature':
      return 'var(--metric-temp)';
    case 'blood_glucose':
      return 'var(--metric-glucose)';
  }
}

export function MetricIcon({
  metric,
  size = 20,
}: {
  metric: MetricWireName;
  size?: number;
}) {
  switch (metric) {
    case 'blood_pressure':
      return <Activity size={size} aria-hidden="true" />;
    case 'weight':
      return <Scale size={size} aria-hidden="true" />;
    case 'heart_rate':
      return <Heart size={size} aria-hidden="true" />;
    case 'spo2':
      return <Wind size={size} aria-hidden="true" />;
    case 'body_temperature':
      return <Thermometer size={size} aria-hidden="true" />;
    case 'blood_glucose':
      return <Droplet size={size} aria-hidden="true" />;
  }
}

export function MetricBadge({
  metric,
  color,
  size = 40,
  children,
}: {
  metric?: MetricWireName;
  color?: string;
  size?: number;
  children?: React.ReactNode;
}) {
  const accent = color ?? (metric ? metricAccentVar(metric) : 'var(--color-primary)');
  return (
    <div
      style={{
        width: size,
        height: size,
        borderRadius: '9999px',
        backgroundColor: `color-mix(in srgb, ${accent} 14%, transparent)`,
        color: accent,
      }}
      className="inline-flex shrink-0 items-center justify-center"
    >
      {children ?? (metric ? <MetricIcon metric={metric} size={Math.round(size * 0.52)} /> : null)}
    </div>
  );
}

export function AppCard({
  children,
  elevated = false,
  className = '',
  padding = 'p-4',
  as: Component = 'div',
  ...rest
}: {
  children: React.ReactNode;
  elevated?: boolean;
  className?: string;
  padding?: string;
  as?: React.ElementType;
} & React.HTMLAttributes<HTMLElement>) {
  return (
    <Component
      style={{
        backgroundColor: 'var(--color-surface-lowest)',
        borderRadius: 'var(--radius-card)',
        border: '1px solid var(--color-outline-variant)',
        boxShadow: elevated ? 'var(--elevation-card)' : 'none',
      }}
      className={`${padding} transition-calm ${className}`}
      {...rest}
    >
      {children}
    </Component>
  );
}

export function SectionHeader({
  title,
  subtitle,
  action,
}: {
  title: string;
  subtitle?: string;
  action?: React.ReactNode;
}) {
  return (
    <div className="flex items-start justify-between gap-3">
      <div>
        <h2 className="type-title m-0" style={{ color: 'var(--color-on-surface)' }}>
          {title}
        </h2>
        {subtitle && (
          <p
            className="m-0 mt-0.5 text-xs"
            style={{ color: 'var(--color-on-surface-variant)' }}
          >
            {subtitle}
          </p>
        )}
      </div>
      {action && <div>{action}</div>}
    </div>
  );
}

export function StatusPill({
  label,
  tone = 'neutral',
  dense = false,
}: {
  label: string;
  tone?: StatusTone;
  dense?: boolean;
}) {
  const toneColor =
    tone === 'positive'
      ? 'var(--color-positive)'
      : tone === 'warning'
        ? 'var(--color-warning)'
        : tone === 'critical'
          ? 'var(--color-critical)'
          : tone === 'primary'
            ? 'var(--color-primary)'
            : 'var(--color-neutral)';

  return (
    <span
      style={{
        backgroundColor: `color-mix(in srgb, ${toneColor} 14%, transparent)`,
        color: toneColor,
        borderRadius: 'var(--radius-pill)',
      }}
      className={`inline-flex items-center gap-1.5 font-semibold ${
        dense ? 'px-2.5 py-0.5 text-xs' : 'px-3 py-1 text-xs'
      }`}
    >
      {tone === 'positive' && <CheckCircle2 size={13} aria-hidden="true" />}
      {(tone === 'warning' || tone === 'critical') && (
        <AlertCircle size={13} aria-hidden="true" />
      )}
      {tone === 'neutral' && <Info size={13} aria-hidden="true" />}
      <span>{label}</span>
    </span>
  );
}

export function StatTile({
  label,
  value,
  unit,
  comparison,
  accent = 'var(--color-primary)',
  sparkline,
  onClick,
}: {
  label: string;
  value: string;
  unit: string;
  comparison?: string | null;
  accent?: string;
  sparkline?: React.ReactNode;
  onClick?: () => void;
}) {
  return (
    <AppCard
      className={onClick ? 'cursor-pointer hover:opacity-95' : ''}
      onClick={onClick}
    >
      <div className="flex items-center justify-between gap-2">
        <span
          className="type-micro truncate"
          style={{ color: 'var(--color-on-surface-variant)' }}
        >
          {label}
        </span>
        <span
          style={{
            width: 10,
            height: 10,
            borderRadius: '9999px',
            backgroundColor: accent,
          }}
          aria-hidden="true"
        />
      </div>
      <div className="mt-2 flex items-baseline gap-1.5">
        <span
          className="type-display tabular-nums"
          style={{ color: 'var(--color-on-surface)' }}
        >
          {value}
        </span>
        <span
          className="text-xs font-medium"
          style={{ color: 'var(--color-on-surface-variant)' }}
        >
          {unit}
        </span>
      </div>
      {comparison && (
        <p
          className="m-0 mt-1.5 text-xs font-medium tabular-nums"
          style={{ color: 'var(--color-secondary)' }}
        >
          {comparison}
        </p>
      )}
      {sparkline && <div className="mt-3 h-10">{sparkline}</div>}
    </AppCard>
  );
}

export function SegmentedControl<T extends string | number>({
  options,
  selected,
  onChange,
  labelBuilder,
  ariaLabel = 'View selector',
}: {
  options: readonly T[];
  selected: T;
  onChange: (value: T) => void;
  labelBuilder?: (option: T) => string;
  ariaLabel?: string;
}) {
  return (
    <div
      role="group"
      aria-label={ariaLabel}
      style={{
        backgroundColor: 'var(--color-surface-low)',
        borderRadius: 'var(--radius-control)',
        border: '1px solid var(--color-outline-variant)',
      }}
      className="inline-flex w-full p-1"
    >
      {options.map((opt) => {
        const isSelected = opt === selected;
        return (
          <button
            key={String(opt)}
            type="button"
            aria-pressed={isSelected}
            onClick={() => onChange(opt)}
            style={{
              backgroundColor: isSelected
                ? 'var(--color-primary)'
                : 'transparent',
              color: isSelected
                ? 'var(--color-on-primary)'
                : 'var(--color-on-surface-variant)',
              borderRadius: 'calc(var(--radius-control) - 4px)',
            }}
            className="touch-target flex-1 cursor-pointer px-3 py-2 text-xs font-semibold transition-calm"
          >
            {labelBuilder ? labelBuilder(opt) : String(opt)}
          </button>
        );
      })}
    </div>
  );
}

export function RangeSelector({
  selected,
  onChange,
}: {
  selected: AnalysisRangeDays;
  onChange: (days: AnalysisRangeDays) => void;
}) {
  const ranges: readonly AnalysisRangeDays[] = [7, 30, 90];
  return (
    <SegmentedControl
      options={ranges}
      selected={selected}
      onChange={onChange}
      ariaLabel="Date range selector"
      labelBuilder={(days) => `${days} Days`}
    />
  );
}

export function SelectableChip({
  label,
  selected,
  onClick,
}: {
  label: string;
  selected: boolean;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      aria-pressed={selected}
      onClick={onClick}
      style={{
        backgroundColor: selected
          ? 'var(--color-primary)'
          : 'var(--color-surface-low)',
        color: selected
          ? 'var(--color-on-primary)'
          : 'var(--color-on-surface)',
        borderColor: selected
          ? 'var(--color-primary)'
          : 'var(--color-outline-variant)',
        borderRadius: 'var(--radius-pill)',
      }}
      className="min-h-[40px] cursor-pointer border px-3.5 py-1.5 text-xs font-semibold transition-calm"
    >
      {label}
    </button>
  );
}

export function EmptyState({
  title,
  message,
  actionLabel,
  onAction,
  icon,
}: {
  title: string;
  message: string;
  actionLabel?: string;
  onAction?: () => void;
  icon?: React.ReactNode;
}) {
  return (
    <AppCard className="flex flex-col items-center py-8 text-center">
      <div
        style={{
          backgroundColor: 'var(--color-surface-low)',
          color: 'var(--color-primary)',
        }}
        className="mb-3 flex h-12 w-12 items-center justify-center rounded-full"
      >
        {icon ?? <Activity size={24} aria-hidden="true" />}
      </div>
      <h3 className="type-title m-0" style={{ color: 'var(--color-on-surface)' }}>
        {title}
      </h3>
      <p
        className="m-0 mt-1.5 max-w-md text-sm"
        style={{ color: 'var(--color-on-surface-variant)' }}
      >
        {message}
      </p>
      {actionLabel && onAction && (
        <button
          type="button"
          onClick={onAction}
          style={{
            backgroundColor: 'var(--color-primary)',
            color: 'var(--color-on-primary)',
            borderRadius: 'var(--radius-control)',
          }}
          className="touch-target mt-4 inline-flex cursor-pointer items-center justify-center px-5 py-2.5 text-sm font-semibold"
        >
          {actionLabel}
        </button>
      )}
    </AppCard>
  );
}

export function ErrorState({
  message,
  onRetry,
}: {
  message: string;
  onRetry?: () => void;
}) {
  return (
    <AppCard
      role="alert"
      className="flex flex-col items-center py-8 text-center"
    >
      <div
        style={{
          backgroundColor: 'var(--color-error-container)',
          color: 'var(--color-on-error-container)',
        }}
        className="mb-3 flex h-12 w-12 items-center justify-center rounded-full"
      >
        <AlertCircle size={24} aria-hidden="true" />
      </div>
      <h3 className="type-title m-0" style={{ color: 'var(--color-on-surface)' }}>
        Something went wrong
      </h3>
      <p
        className="m-0 mt-1.5 max-w-md text-sm"
        style={{ color: 'var(--color-on-surface-variant)' }}
      >
        {message}
      </p>
      {onRetry && (
        <button
          type="button"
          onClick={onRetry}
          style={{
            backgroundColor: 'var(--color-primary)',
            color: 'var(--color-on-primary)',
            borderRadius: 'var(--radius-control)',
          }}
          className="touch-target mt-4 inline-flex cursor-pointer items-center justify-center px-5 py-2.5 text-sm font-semibold"
        >
          Try again
        </button>
      )}
    </AppCard>
  );
}

export function LoadingState({
  lines = 3,
  label = 'Loading health records…',
}: {
  lines?: number;
  label?: string;
}) {
  return (
    <AppCard role="status" aria-busy="true" aria-label={label} className="space-y-3">
      <span className="sr-only">{label}</span>
      {Array.from({ length: lines }).map((_, idx) => (
        <div
          key={idx}
          style={{
            backgroundColor: 'var(--color-surface-container)',
            borderRadius: 'var(--radius-control)',
          }}
          className="h-6 w-full animate-pulse"
        />
      ))}
    </AppCard>
  );
}
