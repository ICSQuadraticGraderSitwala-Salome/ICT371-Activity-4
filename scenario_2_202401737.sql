-- SCENARIO 2: Computer Laboratory Reservations
-- Student: 202401737

DROP TABLE IF EXISTS reservations;
DROP TABLE IF EXISTS lab_sessions;

CREATE TABLE lab_sessions (
    session_id SERIAL PRIMARY KEY,
    session_name VARCHAR(100),
    available_workstations INT NOT NULL
);

CREATE TABLE reservations (
    reservation_id SERIAL PRIMARY KEY,
    session_id INT REFERENCES lab_sessions(session_id),
    lecturer_name VARCHAR(100),
    num_workstations INT NOT NULL,
    status VARCHAR(20) DEFAULT 'Reserved'
);

INSERT INTO lab_sessions (session_name, available_workstations) VALUES
('ICT371 Practical - Monday', 30),
('ICT372 Networking - Tuesday', 5),
('ICT373 Database - Wednesday', 25);

DO $$
DECLARE
    v_workstations INT;
    v_session_name VARCHAR;
BEGIN
    SELECT available_workstations, session_name INTO v_workstations, v_session_name
    FROM lab_sessions WHERE session_id = 2;

    IF v_workstations = 0 THEN
        RAISE NOTICE 'Session % is FULL', v_session_name;
    ELSIF v_workstations <= 5 THEN
        RAISE NOTICE 'Session % is NEARLY FULL - only % workstations left', v_session_name, v_workstations;
    ELSE
        RAISE NOTICE 'Session % has ENOUGH workstations: %', v_session_name, v_workstations;
    END IF;
END $$;



DO $$
DECLARE
    i INT := 1;
BEGIN
    RAISE NOTICE '--- Session Preparation Reminders ---';
    WHILE i <= 3 LOOP
        RAISE NOTICE 'Preparation Reminder %: Check lab equipment', i;
        i := i + 1;
    END LOOP;

    RAISE NOTICE '--- Workstation Checks ---';
    FOR j IN 1..3 LOOP
        RAISE NOTICE 'Workstation Check number % completed', j;
    END LOOP;
END $$;


-- STEP 4
CREATE OR REPLACE PROCEDURE reserve_workstations(
    p_session_id INT,
    p_lecturer VARCHAR,
    p_num INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_available INT;
BEGIN
    IF p_num <= 0 THEN
        RAISE EXCEPTION 'Invalid quantity: Number of workstations must be greater than zero';
    END IF;

    SELECT available_workstations INTO v_available FROM lab_sessions WHERE session_id = p_session_id;

    IF NOT FOUND THEN
        RAISE NOTICE 'Session ID % does not exist', p_session_id;
        RETURN;
    END IF;

    IF v_available >= p_num THEN
        UPDATE lab_sessions SET available_workstations = available_workstations - p_num
        WHERE session_id = p_session_id;

        INSERT INTO reservations(session_id, lecturer_name, num_workstations, status)
        VALUES (p_session_id, p_lecturer, p_num, 'Reserved');

        RAISE NOTICE 'Reserved % workstations for % in session %', p_num, p_lecturer, p_session_id;
    ELSE
        RAISE NOTICE 'FAILED: Not enough workstations in session %. Available: %, Requested: %', p_session_id, v_available, p_num;
    END IF;
END $$;


-- STEP 5
CALL reserve_workstations(1, 'Dr. Banda', 10);
CALL reserve_workstations(1, 'Mr. Phiri', 5);
CALL reserve_workstations(1, 'Mrs. Zulu', 50); -- will fail

SELECT * FROM lab_sessions;
SELECT * FROM reservations;


-- STEP 6
CREATE OR REPLACE PROCEDURE cancel_reservation(p_reservation_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_status VARCHAR;
    v_session_id INT;
    v_num INT;
BEGIN
    SELECT status, session_id, num_workstations INTO v_status, v_session_id, v_num
    FROM reservations WHERE reservation_id = p_reservation_id;

    IF NOT FOUND THEN
        RAISE NOTICE 'Reservation % not found', p_reservation_id;
        RETURN;
    END IF;

    IF v_status = 'Cancelled' THEN
        RAISE NOTICE 'Reservation % is already cancelled - workstations will NOT be released again', p_reservation_id;
        RETURN;
    END IF;

    UPDATE lab_sessions SET available_workstations = available_workstations + v_num
    WHERE session_id = v_session_id;

    UPDATE reservations SET status = 'Cancelled' WHERE reservation_id = p_reservation_id;

    RAISE NOTICE 'Reservation % cancelled, % workstations released', p_reservation_id, v_num;
END $$;

CALL cancel_reservation(1);
CALL cancel_reservation(1);

SELECT * FROM lab_sessions;
SELECT * FROM reservations;


-- STEP 7
DO $$
DECLARE
    cur CURSOR FOR SELECT session_id, session_name, available_workstations FROM lab_sessions WHERE available_workstations <= 5;
    rec RECORD;
BEGIN
    RAISE NOTICE '--- Sessions with few workstations remaining ---';
    OPEN cur;
    LOOP
        FETCH cur INTO rec;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Session ID %: % has only % workstations left', rec.session_id, rec.session_name, rec.available_workstations;
    END LOOP;
    CLOSE cur;
END $$;


-- STEP 8
DO $$
BEGIN
    CALL reserve_workstations(2, 'Dr. Test', 0);
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Exception caught: %', SQLERRM;
END $$;


-- STEP 9
SELECT * FROM lab_sessions;
SELECT * FROM reservations;
