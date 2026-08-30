import { haversineDistanceKm } from './haversine';

describe('haversineDistanceKm', () => {
  it('is 0 for the same point', () => {
    expect(haversineDistanceKm(-22.9711, -43.1822, -22.9711, -43.1822)).toBe(0);
  });

  it('matches the known real-world distance between São Paulo and Rio de Janeiro (~357km)', () => {
    const distance = haversineDistanceKm(
      -23.5505,
      -46.6333,
      -22.9068,
      -43.1729,
    );
    expect(distance).toBeGreaterThan(350);
    expect(distance).toBeLessThan(365);
  });

  it('is symmetric regardless of argument order', () => {
    const ab = haversineDistanceKm(-23.5505, -46.6333, -22.9068, -43.1729);
    const ba = haversineDistanceKm(-22.9068, -43.1729, -23.5505, -46.6333);
    expect(ab).toBeCloseTo(ba, 10);
  });
});
