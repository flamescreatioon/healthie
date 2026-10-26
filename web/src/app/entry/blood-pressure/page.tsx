'use client';

import React, { Suspense } from 'react';
import { useSearchParams } from 'next/navigation';
import { BloodPressureEntryView } from '@/components/screens/blood-pressure-entry-view';
import { LoadingState } from '@/components/ui/primitives';

function BloodPressureEntryInner() {
  const searchParams = useSearchParams();
  const editId = searchParams.get('edit') ?? undefined;
  return <BloodPressureEntryView editId={editId} />;
}

export default function BloodPressureEntryPage() {
  return (
    <Suspense fallback={<LoadingState lines={3} label="Loading blood pressure entry..." />}>
      <BloodPressureEntryInner />
    </Suspense>
  );
}
