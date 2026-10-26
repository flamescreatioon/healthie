import React from 'react';
import { describe, expect, it, vi } from 'vitest';
import { render } from '@testing-library/react';
import { fireEvent } from '@testing-library/dom';
import {
  LoadingState,
  EmptyState,
  ErrorState,
  StatusPill,
} from '@/components/ui/primitives';
import { TrendChart } from '@/components/charts/charts';
import { AppProviders } from '@/components/providers/app-providers';
import { BloodPressureEntryView } from '@/components/screens/blood-pressure-entry-view';
import {
  FakeMeasurementRepository,
  FakeProfileRepository,
  FakeReminderRepository,
} from '@/domain';

// Mock next/navigation for entry view tests
vi.mock('next/navigation', () => ({
  useRouter: () => ({
    push: vi.fn(),
    replace: vi.fn(),
    back: vi.fn(),
  }),
  usePathname: () => '/entry/blood-pressure',
  useSearchParams: () => new URLSearchParams(),
}));

describe('UI Primitives, 4-State Coverage & Accessible Charts', () => {
  it('renders LoadingState, EmptyState, ErrorState, and StatusPill with text labels', () => {
    const loadingView = render(<LoadingState lines={2} label="Loading vitals..." />);
    expect(loadingView.getByRole('status')).toHaveAttribute(
      'aria-label',
      'Loading vitals...',
    );
    loadingView.unmount();

    const emptyView = render(
      <EmptyState
        title="No readings yet"
        message="Log your first blood pressure reading."
      />,
    );
    expect(emptyView.getByText('No readings yet')).toBeInTheDocument();
    emptyView.unmount();

    const errorView = render(<ErrorState message="IndexedDB is blocked." />);
    expect(errorView.getByRole('alert')).toHaveTextContent('IndexedDB is blocked.');
    errorView.unmount();

    const pillView = render(
      <StatusPill label="Stage 1 Hypertension" tone="warning" />,
    );
    expect(pillView.getByText('Stage 1 Hypertension')).toBeInTheDocument();
    pillView.unmount();
  });

  it('renders TrendChart with a screen-reader accessible .sr-only summary', () => {
    const view = render(
      <TrendChart
        title="Blood pressure trend"
        unit="mmHg"
        primaryLabel="Systolic"
        primaryColor="#e11d48"
        secondaryLabel="Diastolic"
        secondaryColor="#fb7185"
        summaryText="Systolic and diastolic blood pressure over 7 days averaging 120/77 mmHg"
        data={[
          { dateLabel: 'May 14', localDay: '2026-05-14', primary: 122, secondary: 78 },
          { dateLabel: 'May 15', localDay: '2026-05-15', primary: 118, secondary: 76 },
        ]}
      />,
    );

    expect(
      view.getByText(
        'Systolic and diastolic blood pressure over 7 days averaging 120/77 mmHg',
      ),
    ).toBeInTheDocument();
  });
});

describe('BloodPressureEntryView — Clinical Validation & Double-Submit Guard', () => {
  it('blocks saving when systolic <= diastolic and saves exactly once on valid input', async () => {
    const measurements = new FakeMeasurementRepository();
    const profiles = new FakeProfileRepository();
    const reminders = new FakeReminderRepository();

    const view = render(
      <AppProviders
        overrideRepositories={{
          measurements,
          profile: profiles,
          reminders,
        }}
      >
        <BloodPressureEntryView />
      </AppProviders>,
    );

    const sysInput = view.getByLabelText(/Systolic \(mmHg\)/i);
    const diaInput = view.getByLabelText(/Diastolic \(mmHg\)/i);

    fireEvent.change(sysInput, { target: { value: '80' } });
    fireEvent.change(diaInput, { target: { value: '85' } });

    const saveButton = view.getByRole('button', {
      name: /Save blood pressure/i,
    });
    fireEvent.click(saveButton);

    expect(
      await view.findByText(/Systolic must be greater than diastolic/i),
    ).toBeInTheDocument();
    expect(await measurements.list({ metricType: 'blood_pressure' })).toHaveLength(
      0,
    );

    // Fix inputs to valid reading and double-click save rapidly
    fireEvent.change(sysInput, { target: { value: '122' } });
    fireEvent.change(diaInput, { target: { value: '78' } });

    fireEvent.click(saveButton);
    fireEvent.click(saveButton);

    await vi.waitFor(async () => {
      const saved = await measurements.list({ metricType: 'blood_pressure' });
      expect(saved).toHaveLength(1);
      expect(saved[0]?.value).toBe(122);
      expect(saved[0]?.secondaryValue).toBe(78);
    });
  });
});
