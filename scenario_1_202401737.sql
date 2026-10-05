DROP TABLE IF EXISTS book_loans CASCADE;
DROP TABLE IF EXISTS books CASCADE;

CREATE TABLE books (
    book_id SERIAL PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    available_copies INT NOT NULL CHECK (available_copies >= 0)
);

CREATE TABLE book_loans (
    loan_id SERIAL PRIMARY KEY,
    student_number VARCHAR(20) NOT NULL,
    book_id INT REFERENCES books(book_id),
    quantity INT NOT NULL CHECK (quantity > 0),
    loan_status VARCHAR(20) DEFAULT 'BORROWED',
    loan_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO books (title, available_copies) VALUES
('Database Systems', 10),
('Operating Systems', 2),
('Computer Networks', 0);

SELECT * FROM books;

DO $$
DECLARE
    v_copies INT;
BEGIN
    SELECT available_copies INTO v_copies FROM books WHERE book_id = 2;
    IF v_copies = 0 THEN
        RAISE NOTICE 'Book ID 2 is UNAVAILABLE';
    ELSIF v_copies <= 2 THEN
        RAISE NOTICE 'Book ID 2 is LOW on copies: % remaining', v_copies;
    ELSE
        RAISE NOTICE 'Book ID 2 is SUFFICIENTLY STOCKED: % copies', v_copies;
    END IF;
END $$;


DO $$
DECLARE
    i INT := 1;
BEGIN
    RAISE NOTICE '--- Overdue Reminders ---';
    WHILE i <= 3 LOOP
        RAISE NOTICE 'Overdue Reminder %: Please return your book', i;
        i := i + 1;
    END LOOP;

    RAISE NOTICE '--- Shelf Numbers ---';
    FOR j IN 1..3 LOOP
        RAISE NOTICE 'Checking shelf number %', j;
    END LOOP;
END $$;

CREATE OR REPLACE PROCEDURE borrow_book(p_student_number VARCHAR, p_book_id INT, p_qty INT)
LANGUAGE plpgsql AS $$
DECLARE
    v_available INT;
BEGIN
    IF p_qty <= 0 THEN
        RAISE EXCEPTION 'Invalid quantity: % must be > 0', p_qty;
    END IF;

    SELECT available_copies INTO v_available FROM books WHERE book_id = p_book_id;
    
    IF v_available >= p_qty THEN
        UPDATE books SET available_copies = available_copies - p_qty WHERE book_id = p_book_id;
        INSERT INTO book_loans (student_number, book_id, quantity, loan_status)
        VALUES (p_student_number, p_book_id, p_qty, 'BORROWED');
        RAISE NOTICE 'Loan SUCCESS: Student % borrowed % copy(s)', p_student_number, p_qty;
    ELSE
        RAISE NOTICE 'Loan FAILED: Only % copies available, requested %', v_available, p_qty;
    END IF;
END $$;

CALL borrow_book('2024001', 1, 2); -- valid
CALL borrow_book('2024002', 2, 1); -- valid
CALL borrow_book('2024003', 3, 1); -- fail, 0 available

SELECT * FROM books;
SELECT * FROM book_loans;


CREATE OR REPLACE PROCEDURE return_book(p_loan_id INT)
LANGUAGE plpgsql AS $$
DECLARE
    v_status VARCHAR;
    v_book_id INT;
    v_qty INT;
BEGIN
    SELECT loan_status, book_id, quantity INTO v_status, v_book_id, v_qty
    FROM book_loans WHERE loan_id = p_loan_id;

    IF v_status = 'RETURNED' THEN
        RAISE NOTICE 'Loan ID % already returned - no action taken', p_loan_id;
    ELSE
        UPDATE book_loans SET loan_status = 'RETURNED' WHERE loan_id = p_loan_id;
        UPDATE books SET available_copies = available_copies + v_qty WHERE book_id = v_book_id;
        RAISE NOTICE 'Loan ID % returned successfully', p_loan_id;
    END IF;
END $$;

CALL return_book(1); -- first return, restores 2 copies
CALL return_book(1); -- second call, must NOT restore again

SELECT * FROM books;
SELECT * FROM book_loans;


DO $$
DECLARE
    low_stock_cursor CURSOR FOR SELECT book_id, title, available_copies FROM books WHERE available_copies <= 2;
    r RECORD;
BEGIN
    RAISE NOTICE '--- Books with few copies ---';
    OPEN low_stock_cursor;
    LOOP
        FETCH low_stock_cursor INTO r;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Book %: % has % copies left', r.book_id, r.title, r.available_copies;
    END LOOP;
    CLOSE low_stock_cursor;
END $$;


DO $$
BEGIN
    CALL borrow_book('2024004', 1, 0);
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'EXCEPTION CAUGHT: %', SQLERRM;
END $$;



SELECT * FROM books;
SELECT * FROM book_loans;

SELECT b.book_id, b.title, b.available_copies, l.loan_id, l.student_number, l.quantity, l.loan_status
FROM books b LEFT JOIN book_loans l ON b.book_id = l.book_id
ORDER BY b.book_id, l.loan_id;