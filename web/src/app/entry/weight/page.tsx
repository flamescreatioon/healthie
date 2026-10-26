'use client';

import React, { Suspense } from 'react';
import { useSearchParams } from 'next/navigation';
import { WeightEntryView } from '@/components/screens/weight-entry-view';
import { LoadingState } from '@/components/ui/primitives';

function WeightEntryInner() {
  const searchParams = useSearchParams();
  const editId = searchParams.get('edit') ?? undefined;
  return <WeightEntryView editId={editId} />;
}

export default function WeightEntryPage() {
  return (
    <Suspense fallback={<LoadingState lines={3} label="Loading weight entry..." />}>
      <WeightEntryInner />
    </Suspense>
  );
}
