'use client';

import React, { Suspense, use } from 'react';
import { GenericMetricEntryView } from '@/components/screens/generic-metric-entry-view';
import { ErrorState, LoadingState } from '@/components/ui/primitives';
import { isMetricWireName } from '@/domain';

function GenericMetricEntryInner({ type }: { type: string }) {
  const normalized = type.replace(/-/g, '_');
  if (!isMetricWireName(normalized)) {
    return <ErrorState message={`Unsupported metric type: ${type}`} />;
  }
  return <GenericMetricEntryView metricType={normalized} />;
}

export default function GenericMetricPage({
  params,
}: {
  params: Promise<{ type: string }>;
}) {
  const { type } = use(params);
  return (
    <Suspense fallback={<LoadingState lines={3} label="Loading metric entry..." />}>
      <GenericMetricEntryInner type={type} />
    </Suspense>
  );
}
