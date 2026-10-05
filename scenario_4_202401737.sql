-- SCENARIO 4: Campus Clinic Medicine Dispensing
-- STEP 1: Create tables

DROP TABLE IF EXISTS dispensing_records;
DROP TABLE IF EXISTS medicines;

CREATE TABLE medicines (
    medicine_id SERIAL PRIMARY KEY,
    medicine_name VARCHAR(100) NOT NULL,
    total_stock INT NOT NULL,
    available_stock INT NOT NULL
);

CREATE TABLE dispensing_records (
    record_id SERIAL PRIMARY KEY,
    medicine_id INT REFERENCES medicines(medicine_id),
    student_number VARCHAR(20) NOT NULL,
    quantity INT NOT NULL,
    status VARCHAR(20) DEFAULT 'Dispensed'
);

INSERT INTO medicines (medicine_name, total_stock, available_stock) VALUES
('Paracetamol 500mg', 100, 100),
('Amoxicillin 250mg', 50, 8),
('Vitamin C 1000mg', 200, 200);


-- STEP 2: IF ELSIF ELSE - check stock level
DO $$
DECLARE
    v_stock INT;
BEGIN
    SELECT available_stock INTO v_stock FROM medicines WHERE medicine_id = 2; -- Amoxicillin 8 left

    IF v_stock = 0 THEN
        RAISE NOTICE 'Medicine ID 2 is OUT OF STOCK';
    ELSIF v_stock <= 10 THEN
        RAISE NOTICE 'Medicine ID 2 is LOW ON STOCK: % remaining', v_stock;
    ELSE
        RAISE NOTICE 'Medicine ID 2 is Sufficiently Stocked: % available', v_stock;
    END IF;
END $$;


-- STEP 3: WHILE + FOR
DO $$
DECLARE
    i INT := 1;
BEGIN
    RAISE NOTICE '--- Stock Review Days ---';
    WHILE i <= 3 LOOP
        RAISE NOTICE 'Stock Review Day %', i;
        i := i + 1;
    END LOOP;

    RAISE NOTICE '--- Shelf Inspections ---';
    FOR j IN 1..3 LOOP
        RAISE NOTICE 'Shelf Inspection number % completed', j;
    END LOOP;
END $$;

-- STEP 4: dispense_medicine procedure
CREATE OR REPLACE PROCEDURE dispense_medicine(
    p_medicine_id INT,
    p_student_no VARCHAR,
    p_qty INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_available INT;
BEGIN
    IF p_qty <= 0 THEN
        RAISE EXCEPTION 'Invalid quantity: Quantity must be greater than zero, got %', p_qty;
    END IF;

    SELECT available_stock INTO v_available FROM medicines WHERE medicine_id = p_medicine_id;

    IF NOT FOUND THEN
        RAISE NOTICE 'Medicine ID % does not exist', p_medicine_id;
        RETURN;
    END IF;

    IF v_available >= p_qty THEN
        UPDATE medicines SET available_stock = available_stock - p_qty
        WHERE medicine_id = p_medicine_id;

        INSERT INTO dispensing_records(medicine_id, student_number, quantity, status)
        VALUES (p_medicine_id, p_student_no, p_qty, 'Dispensed');

        RAISE NOTICE 'Dispensed % units of medicine % to %', p_qty, p_medicine_id, p_student_no;
    ELSE
        RAISE NOTICE 'FAILED: Not enough stock for medicine %. Available: %, Requested: %', p_medicine_id, v_available, p_qty;
    END IF;
END $$;

-- STEP 5: Two valid, one exceeding
CALL dispense_medicine(1, '202401737', 20);
CALL dispense_medicine(1, '202400112', 10);
CALL dispense_medicine(2, '202400999', 50); -- will fail, only 8 left

SELECT * FROM medicines;
SELECT * FROM dispensing_records;


-- STEP 6: reverse_dispensing procedure
CREATE OR REPLACE PROCEDURE reverse_dispensing(p_record_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_status VARCHAR;
    v_medicine_id INT;
    v_qty INT;
BEGIN
    SELECT status, medicine_id, quantity INTO v_status, v_medicine_id, v_qty
    FROM dispensing_records WHERE record_id = p_record_id;

    IF NOT FOUND THEN
        RAISE NOTICE 'Record % not found', p_record_id;
        RETURN;
    END IF;

    IF v_status = 'Reversed' THEN
        RAISE NOTICE 'Record % is already reversed - stock will NOT be restored again', p_record_id;
        RETURN;
    END IF;

    UPDATE medicines SET available_stock = available_stock + v_qty
    WHERE medicine_id = v_medicine_id;

    UPDATE dispensing_records SET status = 'Reversed' WHERE record_id = p_record_id;

    RAISE NOTICE 'Record % reversed, % units restored to medicine %', p_record_id, v_qty, v_medicine_id;
END $$;

CALL reverse_dispensing(1);
CALL reverse_dispensing(1);

SELECT * FROM medicines;
SELECT * FROM dispensing_records;

-- STEP 7: Explicit cursor for low stock
DO $$
DECLARE
    cur CURSOR FOR SELECT medicine_id, medicine_name, available_stock FROM medicines WHERE available_stock <= 10;
    rec RECORD;
BEGIN
    RAISE NOTICE '--- Medicines below low-stock threshold (10) ---';
    OPEN cur;
    LOOP
        FETCH cur INTO rec;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Medicine ID %: % has only % units left', rec.medicine_id, rec.medicine_name, rec.available_stock;
    END LOOP;
    CLOSE cur;
END $$;

-- STEP 8: EXCEPTION block for negative quantity
DO $$
BEGIN
    CALL dispense_medicine(1, '202401737', -5);
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Exception caught: %', SQLERRM;
END $$;


-- STEP 9: Final state
SELECT * FROM medicines;
SELECT * FROM dispensing_records;