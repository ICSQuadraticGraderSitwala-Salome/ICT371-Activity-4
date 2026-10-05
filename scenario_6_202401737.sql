-- SCENARIO 6: University Event Seat Booking
-- STEP 1: Create tables

DROP TABLE IF EXISTS bookings;
DROP TABLE IF EXISTS events;

CREATE TABLE events (
    event_id SERIAL PRIMARY KEY,
    event_name VARCHAR(100) NOT NULL,
    total_seats INT NOT NULL,
    available_seats INT NOT NULL
);

CREATE TABLE bookings (
    booking_id SERIAL PRIMARY KEY,
    event_id INT REFERENCES events(event_id),
    student_number VARCHAR(20) NOT NULL,
    num_seats INT NOT NULL,
    status VARCHAR(20) DEFAULT 'Booked'
);

INSERT INTO events (event_name, total_seats, available_seats) VALUES
('Graduation Ceremony 2026', 500, 500),
('Tech Innovation Expo', 100, 6),
('Career Fair Day', 200, 200);


-- STEP 2: IF ELSIF ELSE - check seat availability
DO $$
DECLARE
    v_seats INT;
BEGIN
    SELECT available_seats INTO v_seats FROM events WHERE event_id = 2; -- Tech Expo has 6 left

    IF v_seats = 0 THEN
        RAISE NOTICE 'Event ID 2 is FULL';
    ELSIF v_seats <= 10 THEN
        RAISE NOTICE 'Event ID 2 is NEARLY FULL: % seats remaining', v_seats;
    ELSE
        RAISE NOTICE 'Event ID 2 has PLENTY OF SEATS: % available', v_seats;
    END IF;
END $$;


-- STEP 3: WHILE + FOR
DO $$
DECLARE
    i INT := 1;
BEGIN
    RAISE NOTICE '--- Booking Reminder Days ---';
    WHILE i <= 3 LOOP
        RAISE NOTICE 'Booking Reminder Day %', i;
        i := i + 1;
    END LOOP;

    RAISE NOTICE '--- Entrance Checks ---';
    FOR j IN 1..3 LOOP
        RAISE NOTICE 'Entrance Check number % completed', j;
    END LOOP;
END $$;




-- STEP 4: book_seats procedure
CREATE OR REPLACE PROCEDURE book_seats(
    p_event_id INT,
    p_student_no VARCHAR,
    p_num INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_available INT;
BEGIN
    IF p_num <= 0 THEN
        RAISE EXCEPTION 'Invalid quantity: Number of seats must be greater than zero, got %', p_num;
    END IF;

    SELECT available_seats INTO v_available FROM events WHERE event_id = p_event_id;

    IF NOT FOUND THEN
        RAISE NOTICE 'Event ID % does not exist', p_event_id;
        RETURN;
    END IF;

    IF v_available >= p_num THEN
        UPDATE events SET available_seats = available_seats - p_num
        WHERE event_id = p_event_id;

        INSERT INTO bookings(event_id, student_number, num_seats, status)
        VALUES (p_event_id, p_student_no, p_num, 'Booked');

        RAISE NOTICE 'Booked % seats for % in event %', p_num, p_student_no, p_event_id;
    ELSE
        RAISE NOTICE 'FAILED: Not enough seats in event %. Available: %, Requested: %', p_event_id, v_available, p_num;
    END IF;
END $$;



-- STEP 5: Two valid, one exceeding
CALL book_seats(1, '202401737', 2);
CALL book_seats(1, '202400112', 3);
CALL book_seats(1, '202400999', 600); -- will fail

SELECT * FROM events;
SELECT * FROM bookings;


-- STEP 6: cancel_booking procedure
CREATE OR REPLACE PROCEDURE cancel_booking(p_booking_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_status VARCHAR;
    v_event_id INT;
    v_num INT;
BEGIN
    SELECT status, event_id, num_seats INTO v_status, v_event_id, v_num
    FROM bookings WHERE booking_id = p_booking_id;

    IF NOT FOUND THEN
        RAISE NOTICE 'Booking % not found', p_booking_id;
        RETURN;
    END IF;

    IF v_status = 'Cancelled' THEN
        RAISE NOTICE 'Booking % is already cancelled - seats will NOT be released again', p_booking_id;
        RETURN;
    END IF;

    UPDATE events SET available_seats = available_seats + v_num
    WHERE event_id = v_event_id;

    UPDATE bookings SET status = 'Cancelled' WHERE booking_id = p_booking_id;

    RAISE NOTICE 'Booking % cancelled, % seats released', p_booking_id, v_num;
END $$;

CALL cancel_booking(1);
CALL cancel_booking(1);

SELECT * FROM events;
SELECT * FROM bookings;


-- STEP 7: Explicit cursor for full or nearly full events
DO $$
DECLARE
    cur CURSOR FOR SELECT event_id, event_name, available_seats FROM events WHERE available_seats <= 10;
    rec RECORD;
BEGIN
    RAISE NOTICE '--- Full or Nearly Full Events ---';
    OPEN cur;
    LOOP
        FETCH cur INTO rec;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Event ID %: % has only % seats left', rec.event_id, rec.event_name, rec.available_seats;
    END LOOP;
    CLOSE cur;
END $$;



-- STEP 8: EXCEPTION block for zero seats
DO $$
BEGIN
    CALL book_seats(1, '202401737', 0);
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Exception caught: %', SQLERRM;
END $$;


-- STEP 9: Final state
SELECT * FROM events;
SELECT * FROM bookings;
