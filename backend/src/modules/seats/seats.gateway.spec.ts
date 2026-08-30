import { SeatsGateway, sessionRoom } from './seats.gateway';

describe('SeatsGateway', () => {
  let gateway: SeatsGateway;
  let seatLockService: { lockSeats: jest.Mock; releaseSeats: jest.Mock };
  let socket: {
    join: jest.Mock;
    emit: jest.Mock;
    data: { user: { userId: number } };
  };
  let toEmitMock: jest.Mock;
  let toMock: jest.Mock;

  beforeEach(() => {
    seatLockService = { lockSeats: jest.fn(), releaseSeats: jest.fn() };
    gateway = new SeatsGateway(seatLockService as never);

    toEmitMock = jest.fn();
    toMock = jest.fn().mockReturnValue({ emit: toEmitMock });
    gateway.server = { to: toMock } as never;

    socket = {
      join: jest.fn().mockResolvedValue(undefined),
      emit: jest.fn(),
      data: { user: { userId: 42 } },
    };
  });

  it('joinSession joins the session room', async () => {
    await gateway.handleJoinSession(socket as never, { sessionId: 7 });

    expect(socket.join).toHaveBeenCalledWith(sessionRoom(7));
  });

  it('lockSeat broadcasts seat_locked to the whole room on success', async () => {
    seatLockService.lockSeats.mockResolvedValue({ success: true });

    await gateway.handleLockSeat(socket as never, { sessionId: 7, seatId: 3 });

    expect(seatLockService.lockSeats).toHaveBeenCalledWith(7, [3], 42);
    expect(socket.join).toHaveBeenCalledWith(sessionRoom(7));
    expect(toMock).toHaveBeenCalledWith(sessionRoom(7));
    expect(toEmitMock).toHaveBeenCalledWith('seat_locked', {
      sessionId: 7,
      seatId: 3,
    });
    expect(socket.emit).not.toHaveBeenCalled();
  });

  it('lockSeat tells only the caller when the seat is unavailable', async () => {
    seatLockService.lockSeats.mockResolvedValue({
      success: false,
      reason: 'Assento já vendido',
    });

    await gateway.handleLockSeat(socket as never, { sessionId: 7, seatId: 3 });

    expect(socket.emit).toHaveBeenCalledWith('lockRejected', {
      sessionId: 7,
      seatId: 3,
      reason: 'Assento já vendido',
    });
    expect(toEmitMock).not.toHaveBeenCalled();
  });

  it('releaseSeat broadcasts seat_released when the caller actually held the seat', async () => {
    seatLockService.releaseSeats.mockResolvedValue([3]);

    await gateway.handleReleaseSeat(socket as never, {
      sessionId: 7,
      seatId: 3,
    });

    expect(seatLockService.releaseSeats).toHaveBeenCalledWith(7, [3], 42);
    expect(toEmitMock).toHaveBeenCalledWith('seat_released', {
      sessionId: 7,
      seatId: 3,
    });
  });

  it('releaseSeat stays silent when the caller never held the seat', async () => {
    seatLockService.releaseSeats.mockResolvedValue([]);

    await gateway.handleReleaseSeat(socket as never, {
      sessionId: 7,
      seatId: 3,
    });

    expect(toEmitMock).not.toHaveBeenCalled();
  });

  it('broadcastSeatLocked emits seat_locked to the session room', () => {
    gateway.broadcastSeatLocked(7, 3);

    expect(toMock).toHaveBeenCalledWith(sessionRoom(7));
    expect(toEmitMock).toHaveBeenCalledWith('seat_locked', {
      sessionId: 7,
      seatId: 3,
    });
  });

  it('broadcastSeatReleased emits seat_released to the session room', () => {
    gateway.broadcastSeatReleased(7, 3);

    expect(toEmitMock).toHaveBeenCalledWith('seat_released', {
      sessionId: 7,
      seatId: 3,
    });
  });

  it('broadcastSeatSold emits seat_sold to the session room', () => {
    gateway.broadcastSeatSold(7, 3);

    expect(toMock).toHaveBeenCalledWith(sessionRoom(7));
    expect(toEmitMock).toHaveBeenCalledWith('seat_sold', {
      sessionId: 7,
      seatId: 3,
    });
  });
});
