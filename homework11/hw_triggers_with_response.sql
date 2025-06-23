-- ДЗ тема: триггеры, поддержка заполнения витрин

DROP SCHEMA IF EXISTS pract_functions CASCADE;
CREATE SCHEMA pract_functions;

SET search_path = pract_functions, publ

-- товары:
CREATE TABLE goods
(
    goods_id    integer PRIMARY KEY,
    good_name   varchar(63) NOT NULL,
    good_price  numeric(12, 2) NOT NULL CHECK (good_price > 0.0)
);
INSERT INTO goods (goods_id, good_name, good_price)
VALUES 	(1, 'Спички хозайственные', .50),
		(2, 'Автомобиль Ferrari FXX K', 185000000.01);

-- Продажи
CREATE TABLE sales
(
    sales_id    integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    good_id     integer REFERENCES goods (goods_id),
    sales_time  timestamp with time zone DEFAULT now(),
    sales_qty   integer CHECK (sales_qty > 0)
);

INSERT INTO sales (good_id, sales_qty) VALUES (1, 10), (1, 1), (1, 120), (2, 1);

-- отчет:
SELECT G.good_name, sum(G.good_price * S.sales_qty)
FROM goods G
INNER JOIN sales S ON S.good_id = G.goods_id
GROUP BY G.good_name;

-- с увеличением объёма данных отчет стал создаваться медленно
-- Принято решение денормализовать БД, создать таблицу
CREATE TABLE good_sum_mart
(
	good_name   varchar(63) NOT NULL,
	sum_sale	numeric(16, 2)NOT NULL
);

-- Создать триггер (на таблице sales) для поддержки.
-- Подсказка: не забыть, что кроме INSERT есть еще UPDATE и DELETE

-- Чем такая схема (витрина+триггер) предпочтительнее отчета, создаваемого "по требованию" (кроме производительности)?
-- Подсказка: В реальной жизни возможны изменения цен.

CREATE OR REPLACE FUNCTION update_good_sum_mart()
RETURNS TRIGGER AS $$
DECLARE
    current_total numeric(16, 2);
BEGIN
    IF TG_OP = 'INSERT' THEN
        SELECT sum_sale INTO current_total FROM good_sum_mart WHERE good_name = (SELECT good_name FROM goods WHERE goods_id = NEW.good_id);

        IF FOUND THEN
            UPDATE good_sum_mart
            SET sum_sale = current_total + (SELECT good_price FROM goods WHERE goods_id = NEW.good_id) * NEW.sales_qty
            WHERE good_name = (SELECT good_name FROM goods WHERE goods_id = NEW.good_id);
        ELSE
            INSERT INTO good_sum_mart (good_name, sum_sale)
            VALUES ((SELECT good_name FROM goods WHERE goods_id = NEW.good_id), (SELECT good_price FROM goods WHERE goods_id = NEW.good_id) * NEW.sales_qty);
        END IF;
        RETURN NEW;

    ELSIF TG_OP = 'UPDATE' THEN
        SELECT sum_sale INTO current_total FROM good_sum_mart WHERE good_name = (SELECT good_name FROM goods WHERE goods_id = OLD.good_id);

        IF FOUND THEN
            UPDATE good_sum_mart
            SET sum_sale = current_total - (SELECT good_price FROM goods WHERE goods_id = OLD.good_id) * OLD.sales_qty
                            + (SELECT good_price FROM goods WHERE goods_id = NEW.good_id) * NEW.sales_qty
            WHERE good_name = (SELECT good_name FROM goods WHERE goods_id = OLD.good_id);
        END IF;
        RETURN NEW;

    ELSIF TG_OP = 'DELETE' THEN
        SELECT sum_sale INTO current_total FROM good_sum_mart WHERE good_name = (SELECT good_name FROM goods WHERE goods_id = OLD.good_id);

        IF FOUND THEN
            UPDATE good_sum_mart
            SET sum_sale = current_total - (SELECT good_price FROM goods WHERE goods_id = OLD.good_id) * OLD.sales_qty
            WHERE good_name = (SELECT good_name FROM goods WHERE goods_id = OLD.good_id);
        END IF;
        RETURN OLD;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER sales_update_good_sum_mart
AFTER INSERT OR UPDATE OR DELETE ON sales
FOR EACH ROW EXECUTE FUNCTION update_good_sum_mart();