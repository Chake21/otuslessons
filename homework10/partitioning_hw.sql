

CREATE TABLE bookings_copy (
                               book_ref     char(6)                  not null,
                               book_date    timestamp with time zone not null,
                               total_amount numeric(10, 2)           not null,
                           PRIMARY KEY (book_ref, book_date)
) PARTITION BY RANGE (book_date);

CREATE TABLE bookings_2016_07 PARTITION OF bookings_copy FOR VALUES FROM ('2016-07-01') TO ('2016-08-01');
CREATE TABLE bookings_2016_08 PARTITION OF bookings_copy FOR VALUES FROM ('2016-08-01') TO ('2016-09-01');
CREATE TABLE bookings_2016_09 PARTITION OF bookings_copy FOR VALUES FROM ('2016-09-01') TO ('2016-10-01');
CREATE TABLE bookings_2016_10 PARTITION OF bookings_copy FOR VALUES FROM ('2016-10-01') TO ('2016-11-01');
CREATE TABLE bookings_2016_11 PARTITION OF bookings_copy FOR VALUES FROM ('2016-11-01') TO ('2016-12-01');
CREATE TABLE bookings_2016_12 PARTITION OF bookings_copy FOR VALUES FROM ('2016-12-01') TO ('2017-01-01');
CREATE TABLE bookings_2017_01 PARTITION OF bookings_copy FOR VALUES FROM ('2017-01-01') TO ('2017-02-01');
CREATE TABLE bookings_2017_02 PARTITION OF bookings_copy FOR VALUES FROM ('2017-02-01') TO ('2017-03-01');
CREATE TABLE bookings_2017_03 PARTITION OF bookings_copy FOR VALUES FROM ('2017-03-01') TO ('2017-04-01');
CREATE TABLE bookings_2017_04 PARTITION OF bookings_copy FOR VALUES FROM ('2017-04-01') TO ('2017-05-01');
CREATE TABLE bookings_2017_05 PARTITION OF bookings_copy FOR VALUES FROM ('2017-05-01') TO ('2017-06-01');
CREATE TABLE bookings_2017_06 PARTITION OF bookings_copy FOR VALUES FROM ('2017-06-01') TO ('2017-07-01');
CREATE TABLE bookings_2017_07 PARTITION OF bookings_copy FOR VALUES FROM ('2017-07-01') TO ('2017-08-01');
CREATE TABLE bookings_2017_08 PARTITION OF bookings_copy FOR VALUES FROM ('2017-08-01') TO ('2017-09-01');
CREATE TABLE bookings_other PARTITION OF bookings_copy DEFAULT;

-- вручную проверяем что по датам все ок, тут все ОК

INSERT INTO bookings_copy
OVERRIDING SYSTEM VALUE
SELECT * FROM bookings;

-- проверяем кол-во
select count(*) from bookings_copy;
select count(*) from bookings;

-- проверяем что все перенеслись корректно
select count(*) from bookings b join bookings_copy bc ON b.book_date = bc.book_date AND b.book_ref = bc.book_ref AND b.total_amount = bc.total_amount;

-- из старой
explain analyse select t.passenger_name from bookings join bookings.tickets t on bookings.book_ref = t.book_ref where book_date BETWEEN '2016-08-01' AND '2016-10-01'; -- 1436 ms

explain analyse select * from bookings where book_date BETWEEN '2016-08-01' AND '2016-09-01'; -- 128 ms
explain analyse select * from bookings where book_date BETWEEN '2016-08-01' AND '2016-10-01'; -- 216 ms

-- из партиционированной
explain analyse select t.passenger_name from bookings.bookings_copy join bookings.tickets t on bookings_copy.book_ref = t.book_ref where book_date BETWEEN '2016-08-01' AND '2016-10-01'; -- 1537 ms
-- для джойна ничего не поменялось по времени выполнения
explain analyse select * from bookings_copy where book_date BETWEEN '2016-08-01' AND '2016-10-01'; -- 73ms
explain analyse select * from bookings_copy where book_date BETWEEN '2016-08-01' AND '2016-09-01'; -- 95ms

-- секционирование помогает не делать сек скан по всей таблице, планировщик сам выбирает партиции из дат запроса, время выполнения уменьшается, что видно из запросов выше

-- вставка, обновление, удаления


INSERT INTO bookings_copy VALUES ('ABCDEF', '2016-09-15', 2000.55); -- ожидаем в партиции bookings_2016_09

select * from bookings_2016_09 WHERE book_ref = 'ABCDEF';

UPDATE bookings_copy SET total_amount = 2100.55 WHERE book_ref = 'ABCDEF'; -- обновление одной

select * from bookings_2016_09 WHERE book_ref = 'ABCDEF';

select count(*) from bookings_copy where total_amount > 800000.00; -- 290 rows

UPDATE bookings_copy SET total_amount = total_amount - 600000.00 WHERE total_amount > 800000.00; -- обновление многих строк

select count(*) from bookings_copy where total_amount > 800000.00; -- 0 rows

DELETE FROM bookings_copy where book_ref = 'ABCDEF'; -- удаление одной строки

select * from bookings_2016_09 WHERE book_ref = 'ABCDEF'; -- нет строк

select count(*) from bookings_copy where total_amount > 790000.00; -- 126 rows

DELETE FROM bookings_copy where total_amount > 790000.00; -- удаление многих строк

select count(*) from bookings_copy where total_amount > 790000.00; -- 0 rows

INSERT INTO bookings_copy VALUES ('ABCDEF', '2023-09-15', 2000.55); -- ожидаем в партиции bookings_other

select * from bookings_other; -- есть



