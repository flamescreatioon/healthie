'use client';

/**
 * Healthie Web Chart Toolkit (`docs/web/06-visualization.md`).
 *
 * Rules:
 * - Aggregate to display granularity (local day).
 * - Discrete dots for sparse series (`dot={true}`), `connectNulls={false}` so
 *   missing days render as genuine gaps, NEVER interpolated to zero.
 * - Tooltips carry value + unit + date.
 * - Screen-reader summary carries the chart's information (`aria-label` + `.sr-only`).
 */

import React from 'react';
import {
  CartesianGrid,
  Line,
  LineChart,
  ReferenceLine,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';

export interface ChartPoint {
  readonly dateLabel: string;
  readonly localDay: string;
  readonly primary: number | null;
  readonly secondary?: number | null;
}

export interface ChartReferenceLine {
  readonly value: number;
  readonly label: string;
  readonly color?: string;
}

export function TrendChart({
  title,
  unit,
  data,
  primaryLabel,
  primaryColor,
  secondaryLabel,
  secondaryColor,
  referenceLines = [],
  precision = 0,
  height = 240,
  summaryText,
}: {
  title: string;
  unit: string;
  data: readonly ChartPoint[];
  primaryLabel: string;
  primaryColor: string;
  secondaryLabel?: string;
  secondaryColor?: string;
  referenceLines?: readonly ChartReferenceLine[];
  precision?: number;
  height?: number;
  summaryText: string;
}) {
  const populatedPoints = data.filter((d) => d.primary !== null);

  return (
    <div role="region" aria-label={`${title} chart`}>
      <p className="sr-only">{summaryText}</p>
      <div style={{ width: '100%', height }}>
        <ResponsiveContainer width="100%" height="100%">
          <LineChart
            data={[...data]}
            margin={{ top: 10, right: 12, bottom: 4, left: -12 }}
          >
            <CartesianGrid
              stroke="var(--chart-grid)"
              strokeDasharray="3 3"
              vertical={false}
            />
            <XAxis
              dataKey="dateLabel"
              tick={{ fill: 'var(--color-on-surface-variant)', fontSize: 11 }}
              tickLine={false}
              axisLine={{ stroke: 'var(--color-outline-variant)' }}
              minTickGap={20}
            />
            <YAxis
              tick={{ fill: 'var(--color-on-surface-variant)', fontSize: 11 }}
              tickLine={false}
              axisLine={false}
              domain={['auto', 'auto']}
            />
            <Tooltip
              content={({ active, payload, label }) => {
                if (!active || !payload || payload.length === 0) return null;
                return (
                  <div
                    style={{
                      backgroundColor: 'var(--color-inverse-surface)',
                      color: 'var(--color-on-inverse-surface)',
                      borderRadius: 'var(--radius-control)',
                    }}
                    className="px-3 py-2 text-xs shadow-md tabular-nums"
                  >
                    <div className="font-semibold">{label}</div>
                    {payload.map((entry) => {
                      if (entry.value === null || entry.value === undefined) {
                        return null;
                      }
                      const num = Number(entry.value).toFixed(precision);
                      return (
                        <div key={String(entry.name)} className="mt-0.5">
                          {entry.name}:{' '}
                          <span className="font-bold">
                            {num} {unit}
                          </span>
                        </div>
                      );
                    })}
                  </div>
                );
              }}
            />
            {referenceLines.map((ref) => (
              <ReferenceLine
                key={`${ref.label}-${ref.value}`}
                y={ref.value}
                stroke={ref.color ?? 'var(--color-outline)'}
                strokeDasharray="4 4"
              />
            ))}
            <Line
              type="monotone"
              name={primaryLabel}
              dataKey="primary"
              stroke={primaryColor}
              strokeWidth={2.5}
              connectNulls={false}
              dot={{ r: 3.5, fill: primaryColor, strokeWidth: 0 }}
              activeDot={{ r: 5 }}
              isAnimationActive={false}
            />
            {secondaryLabel && secondaryColor && (
              <Line
                type="monotone"
                name={secondaryLabel}
                dataKey="secondary"
                stroke={secondaryColor}
                strokeWidth={2}
                connectNulls={false}
                dot={{ r: 3, fill: secondaryColor, strokeWidth: 0 }}
                isAnimationActive={false}
              />
            )}
          </LineChart>
        </ResponsiveContainer>
      </div>
      {/* Accessible data summary table for screen readers */}
      <table className="sr-only">
        <caption>{title} data points</caption>
        <thead>
          <tr>
            <th scope="col">Date</th>
            <th scope="col">
              {primaryLabel} ({unit})
            </th>
            {secondaryLabel && (
              <th scope="col">
                {secondaryLabel} ({unit})
              </th>
            )}
          </tr>
        </thead>
        <tbody>
          {populatedPoints.map((pt) => (
            <tr key={pt.localDay}>
              <td>{pt.dateLabel}</td>
              <td>{pt.primary?.toFixed(precision)}</td>
              {secondaryLabel && (
                <td>
                  {pt.secondary !== null && pt.secondary !== undefined
                    ? pt.secondary.toFixed(precision)
                    : '—'}
                </td>
              )}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

/**
 * Pure SVG Sparkline so stat tiles render cleanly even in SSR/unit tests without
 * layout-measurement delays. Respects gaps (`null` values break the polyline).
 */
export function Sparkline({
  values,
  color = 'var(--color-primary)',
  height = 44,
  ariaLabel = 'Recent trend sparkline',
}: {
  values: readonly (number | null)[];
  color?: string;
  height?: number;
  ariaLabel?: string;
}) {
  const numeric = values.filter((v): v is number => v !== null);
  if (numeric.length === 0) {
    return (
      <div
        className="flex items-center justify-center text-xs"
        style={{ height, color: 'var(--color-on-surface-variant)' }}
      >
        No recent points
      </div>
    );
  }

  const min = Math.min(...numeric);
  const max = Math.max(...numeric);
  const span = max - min === 0 ? 1 : max - min;
  const width = 160;
  const pad = 6;

  const segments: string[][] = [[]];
  values.forEach((v, idx) => {
    if (v === null) {
      if (segments[segments.length - 1]!.length > 0) {
        segments.push([]);
      }
      return;
    }
    const x =
      values.length === 1
        ? width / 2
        : pad + (idx / (values.length - 1)) * (width - pad * 2);
    const y =
      height - pad - ((v - min) / span) * (height - pad * 2);
    segments[segments.length - 1]!.push(`${x.toFixed(1)},${y.toFixed(1)}`);
  });

  return (
    <svg
      viewBox={`0 0 ${width} ${height}`}
      className="w-full overflow-visible"
      style={{ height }}
      role="img"
      aria-label={ariaLabel}
    >
      {segments
        .filter((s) => s.length > 0)
        .map((pts, idx) =>
          pts.length === 1 ? (
            <circle
              key={idx}
              cx={pts[0]!.split(',')[0]}
              cy={pts[0]!.split(',')[1]}
              r={3.5}
              fill={color}
            />
          ) : (
            <polyline
              key={idx}
              fill="none"
              stroke={color}
              strokeWidth={2.2}
              strokeLinecap="round"
              strokeLinejoin="round"
              points={pts.join(' ')}
            />
          ),
        )}
    </svg>
  );
}

export interface DistributionSegment {
  readonly label: string;
  readonly count: number;
  readonly color: string;
}

export function DistributionBar({
  segments,
  total,
}: {
  segments: readonly DistributionSegment[];
  total: number;
}) {
  if (total === 0) return null;
  return (
    <div>
      <div
        className="flex h-3 w-full overflow-hidden"
        style={{
          borderRadius: 'var(--radius-pill)',
          backgroundColor: 'var(--color-surface-low)',
        }}
        role="img"
        aria-label="Guideline category distribution"
      >
        {segments
          .filter((s) => s.count > 0)
          .map((seg) => {
            const pct = (seg.count / total) * 100;
            return (
              <div
                key={seg.label}
                style={{ width: `${pct}%`, backgroundColor: seg.color }}
                title={`${seg.label}: ${seg.count} (${Math.round(pct)}%)`}
              />
            );
          })}
      </div>
      <div className="mt-3 grid grid-cols-2 gap-2 sm:grid-cols-3">
        {segments.map((seg) => {
          const pct = total === 0 ? 0 : Math.round((seg.count / total) * 100);
          return (
            <div key={seg.label} className="flex items-center gap-2 text-xs">
              <span
                style={{
                  width: 8,
                  height: 8,
                  borderRadius: '9999px',
                  backgroundColor: seg.color,
                }}
                aria-hidden="true"
              />
              <span style={{ color: 'var(--color-on-surface)' }} className="font-medium">
                {seg.label}
              </span>
              <span
                style={{ color: 'var(--color-on-surface-variant)' }}
                className="tabular-nums"
              >
                {seg.count} ({pct}%)
              </span>
            </div>
          );
        })}
      </div>
    </div>
  );
}

export function GoalMeter({
  label,
  currentLabel,
  targetLabel,
  percentAchieved,
}: {
  label: string;
  currentLabel: string;
  targetLabel: string;
  percentAchieved: number;
}) {
  const clampedPct = Math.max(0, Math.min(100, Math.round(percentAchieved * 100)));
  return (
    <div>
      <div className="flex items-center justify-between text-xs">
        <span className="font-semibold" style={{ color: 'var(--color-on-surface)' }}>
          {label}
        </span>
        <span
          className="tabular-nums"
          style={{ color: 'var(--color-on-surface-variant)' }}
        >
          {currentLabel} → {targetLabel} ({clampedPct}%)
        </span>
      </div>
      <div
        className="mt-2 h-2.5 w-full overflow-hidden"
        style={{
          borderRadius: 'var(--radius-pill)',
          backgroundColor: 'var(--color-surface-low)',
        }}
        role="progressbar"
        aria-valuenow={clampedPct}
        aria-valuemin={0}
        aria-valuemax={100}
        aria-label={label}
      >
        <div
          style={{
            width: `${clampedPct}%`,
            backgroundColor: 'var(--color-primary)',
          }}
          className="h-full transition-calm"
        />
      </div>
    </div>
  );
}
