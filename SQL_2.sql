/* Книга в подарок. Вывести название книги, автора, цену и количество. 
Для тех книг, количество которых на складе выше среднего значения, вывести 
в качестве подарка книгу и автора, через запятую, с самой маленькой ценой 
на складе, столбец назвать Подарок. Для остальных книг поставить прочерк.
Информацию отсортировать по названию книг. */
   
SELECT title, author, price, amount, 
       IF(amount > (SELECT AVG(amount) FROM book),
          (SELECT CONCAT(title, ', ', author) FROM book 
           WHERE price = (SELECT MIN(price) FROM book) 
           GROUP BY title, author),
          '-') AS Подарок                                       
FROM book
ORDER BY 1; 


/* Создать таблицу correct в которую вынести сведения о тех книгах из 
таблицы supply, которые отличаются по цене от имеющихся на складе. 
Указать количество и цену книг на складе и в таблице supply. */

CREATE TABLE correct AS
SELECT book.author, book.title, book.amount AS amount_b, supply.amount AS amount_s, book.price AS price_b, supply.price AS price_s
FROM book, supply
WHERE book.author=supply.author AND book.title=supply.title
      AND book.price!=supply.price;

SELECT * FROM correct;


/* Организовать выставку книг таким образом, чтобы в каждом городе книги одного и того
же автора были разные. В зависимомти от количества различных книг у автора, распределить
их по городам: если одна книга - Москва, если две - Москва и Санкт-Петербург, три и более - 
добавить Владивосток. Столбцы назвать Автор, Грода, Книги. Города и книги вывести 
через запятую. Отсортировать сначала по автору, затем по названию книг. */

SELECT name_author AS Автор,
       CASE
       WHEN count(book.title)=1 THEN 'Москва'
       WHEN count(book.title)=2 THEN CONCAT_WS(', ','Москва','Санкт-Петербург')
       ELSE CONCAT_WS(', ','Москва','Санкт-Петербург', 'Владивосток')
       END AS Города,
       GROUP_CONCAT(DISTINCT title ORDER BY title SEPARATOR ", ") AS Книги
FROM 
    author 
    JOIN book USING(author_id)
       
GROUP BY name_author
ORDER BY 1, 3; 


/* Удалить из таблицы book три книги, которых осталось на складе наименьшее 
количество (найти через LIMIT, сохранить их в отдельной таблице, как подарочные). 
Добавить к таблице book новый столбец Подарок. В качестве подарка добавить 
удаленные ранее книги: если book.amount выше среднего значения - в подарок 
идет книга, с наименьшим количеством из подарочных, иначе - в подарок идет 
книга с наибольшим количеством(из подарочных). */

CREATE TABLE present AS
SELECT title, amount
   FROM book
   ORDER BY amount 
   LIMIT 3;
   
SELECT * FROM present;

DELETE book
FROM
   book
   JOIN present USING (title);
   
ALTER TABLE book ADD Подарок VARCHAR(50);

SELECT  DISTINCT book.title, author_id, genre_id, price, book.amount, 
        CASE
           WHEN book.amount > (SELECT AVG(book.amount) FROM book) 
             THEN (SELECT title FROM present ORDER BY present.amount LIMIT 1)
           ELSE (SELECT title FROM present ORDER BY present.amount DESC LIMIT 1)
        END AS Подарок
FROM
    book
    CROSS JOIN present;


/* Составить рейтинг покупателей. 
   Вывести список клиентов, оплативших хотя бы одну книгу, города проживания, 
   общее количество приобретенных книг, стоимость всех покупок, в последнем 
   столбце: список этих книг, каждая с новой строки, у названия каждой книги 
   через дефис указать в каком количестве они приобретены. Столбцы назвать 
   Покупатель, Город. Книг_оплачено, Стоимость, Количество. Отсортировать по 
   убыванию стоимости. */
SELECT name_client AS Покупатель, 
       name_city AS Город, 
       SUM(buy_book.amount) AS Книг_оплачено,
       SUM(buy_book.amount * book.price) AS Стоимость,
       GROUP_CONCAT(CONCAT(title, '-', buy_book.amount) ORDER BY title SEPARATOR '\n') AS Количество 
FROM book
     JOIN buy_book USING (book_id)
     JOIN buy USING (buy_id)
     JOIN client USING (client_id)
     JOIN city USING (city_id)
     JOIN buy_step USING (buy_id)
     JOIN step USING (step_id)
WHERE name_step = 'Оплата' AND date_step_end IS NOT NULL    
GROUP BY name_client, name_city
ORDER BY 4 DESC;


/* Отследить, как осуществляется транспортировка и доставка оплаченных заказов.
Для тех заказов, которые прошли этап транспортировки, вывести количество дней 
за которое заказ реально доставлен, если заказ доставлен с опозданием, указать 
количество дней задержки, в противном случае вывести 0. Вывести в отдельном 
столбце информацию по доставке заказа: если он доставлен указать за сколько дней, 
если нет, поставить "-". */

CREATE TABLE delivery_1 AS
      SELECT buy_id,
             name_client AS Клиент,            
             name_city AS Город,
             days_delivery AS Дней,
             DATEDIFF(date_step_end, date_step_beg) AS Трансп_ка, 
             GREATEST(DATEDIFF(date_step_end, date_step_beg) - days_delivery, 0) AS Опоздание
        FROM city 
             JOIN client USING (city_id) 
             JOIN buy USING (client_id)
             JOIN buy_step USING (buy_id)
             JOIN step USING (step_id)
       WHERE (name_step = 'Транспортировка') AND date_step_end IS NOT NULL;    
SELECT * FROM delivery_1;

CREATE TABLE delivery_2 AS
      SELECT buy_id,
             IF(date_step_end IS NOT NULL, DATEDIFF(date_step_end, date_step_beg)+1, '-') AS Доставка
        FROM buy 
             JOIN buy_step USING (buy_id)
             JOIN step USING (step_id)
       WHERE name_step = 'Доставка';    
SELECT * FROM delivery_2;

SELECT delivery_1.buy_id, delivery_1.Клиент, delivery_1.Город, 
       Дней, Трансп_ка, Опоздание, Доставка
  FROM delivery_1
       JOIN delivery_2 ON delivery_1.buy_id = delivery_2.buy_id;


/* Вывести результаты тестирования для всех студентов, для принятия решения 
о начислении им стипендии или отчислении. Для каждого студента перечислить 
дисциплины, которые он сдавал (через '/'), результаты попыток (через ','), 
количество попыток и их успешность, значение которой округлить до двух знаков. 
В последнем столбце вывести решение о начислении стипендии: повышенная ст., 
стипендия, прочерк или отчисление. */

WITH sum_correct (n_student, n_subject, d_attempt, sum_corr, count_corr)
AS (
    SELECT name_student, name_subject, date_attempt, 
           SUM(is_correct), COUNT(is_correct) 
     FROM testing
          JOIN question USING (question_id)
          JOIN answer USING(answer_id)
          JOIN subject USING(subject_id)
          JOIN attempt USING(attempt_id)
          RIGHT JOIN student USING(student_id)
 GROUP BY name_student, name_subject, date_attempt
    )
SELECT n_student AS Студенты, 
       GROUP_CONCAT(DISTINCT n_subject ORDER BY n_subject SEPARATOR '/') AS Дисциплины,
       GROUP_CONCAT(sum_corr) AS Результаты,
       COUNT(n_subject) AS Попыток,
       ROUND(SUM(sum_corr)/SUM(count_corr)*100, 2) AS Успешность,
       CASE
          WHEN SUM(sum_corr)/SUM(count_corr)*100 = 100 THEN 'Повышенная стипендия'
          WHEN SUM(sum_corr)/SUM(count_corr)*100 BETWEEN 40 AND 99 THEN 'Стипендия'
          WHEN SUM(sum_corr) IS NULL THEN 'Отчисление'
          ELSE '-'
       END AS Решение
 FROM sum_correct
GROUP BY n_student, count_corr 
ORDER BY Успешность DESC;  


/* Добавить нового студента в таблицу студентов.
   В таблицу attempt добавить все предметы и случайные даты для каждой попытки.
   Случайным образом выбрать три вопроса по первой дисциплине, тестирование по 
   которой собирается проходить новый студент и добавить их в таблицу testing. */

INSERT INTO student (name_student) 
VALUES ("Иванов Александр");
SELECT * FROM student;

INSERT INTO attempt (student_id, subject_id, date_attempt) 
SELECT student_id, subject_id, DATE_ADD(NOW(), INTERVAL FLOOR(RAND() * 15) day) 
FROM student
     CROSS JOIN subject 
WHERE student_id = (SELECT MAX(student_id) FROM student);
SELECT * FROM attempt;

INSERT INTO testing(attempt_id, question_id)
SELECT attempt_id, question_id
FROM attempt
     JOIN question USING(subject_id)
WHERE student_id IN (SELECT MAX(student_id) from student) 
      AND subject_id = 1
ORDER BY rand()
LIMIT 3;
SELECT * FROM testing;







