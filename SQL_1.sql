/* Для каждой пофессиональной области вывести самого молодого соискателя, дату его рождения и возраст.
Дату рождения вывести в формате: день месяца с английским суффиксом, английское название месяца,
значение года, состоящее из двух последних цифр.
Столбцы назвать: Специализация, Самый_молодой, Дата_рождения, Возраст.
Информацию отсортировать по возрасту.
*/
SELECT specialisation AS Специализация, 
       SUBSTRING_INDEX(GROUP_CONCAT(applicant ORDER BY date_birth DESC SEPARATOR ";"),
       ';', 1) AS Самый_молодой,
       (FROM_UNIXTIME(MAX(UNIX_TIMESTAMP(date_birth)), "%D %M %y")) AS Дата_рождения, 
       2022 - YEAR(FROM_UNIXTIME(MAX(UNIX_TIMESTAMP(date_birth)))) AS Возраст

FROM resume
GROUP BY specialisation
ORDER BY 4;


/* запрос к таблице resume */
SELECT 
    "IT" AS Специализация,
    COUNT(applicant) AS Количество,
    MIN(min_salary) AS Мин_зарплата,
    MAX(min_salary) AS Макс_зарплата,
    GROUP_CONCAT(applicant order by applicant separator ',') AS Соискатели 
FROM resume
WHERE specialisation = 'IT' 
UNION
SELECT 
    "Строительство",
    COUNT(applicant),
    MIN(min_salary),
    MAX(min_salary),
    GROUP_CONCAT(applicant order by applicant separator ',')
FROM resume
WHERE specialisation = 'Строительство' 
UNION
SELECT 
    "Продажи",
    COUNT(applicant),
    MIN(min_salary),
    MAX(min_salary),
    GROUP_CONCAT(applicant order by applicant separator ',')
FROM resume
WHERE specialisation = 'Продажи' 
UNION
SELECT 
     "Транспорт",
    COUNT(applicant),
    MIN(min_salary),
    MAX(min_salary),
    GROUP_CONCAT(applicant order by applicant separator ',')
FROM resume
WHERE specialisation = 'Транспорт' 
UNION
SELECT
    "Юристы",
    COUNT(applicant),
    MIN(min_salary),
    MAX(min_salary),
    GROUP_CONCAT(applicant order by applicant separator ',')
FROM resume
WHERE specialisation = 'Юристы' 


/* Вычислить, сколько месяцев работает библиотека (в отдельной таблице). 
Для этого сравнить даты самой первой выдачи книги с самой последней датой 
регистрации выдачи или возврата книги. Результат назвать - Период.
Вывести информацию о книгах, которые за этот период еще никто не читал.  
Столбцы назвать Название, Автор, Жанр, Издательство и Доступно (available_numbers).
Информацию отсортировать сначала по количеству книг в убывающем порядке, затем 
по названию книг в алфавитном порядке. */

SELECT MIN(borrow_date), MAX(borrow_date), MAX(return_date),
       GREATEST(MONTH(MAX(return_date)),MONTH(MAX(borrow_date))) - MONTH(MIN(borrow_date)) AS Период
FROM book_reader;

SELECT title AS Название, author_name AS Автор, genre_name AS Жанр, 
       publisher_name AS Издательство, available_numbers AS Доступно
FROM
    genre 
    JOIN book USING (genre_id)    
    LEFT JOIN book_reader USING (book_id) 
    JOIN book_author USING (book_id)
    JOIN author USING (author_id)
    JOIN publisher USING (publisher_id)
WHERE borrow_date IS NULL
ORDER BY 5 DESC, 1;


/* Вывести список гостей, проживающих в гостинице, тип занимаемого номера, 
перечень заказанных услуг (каждая услуга с новой строки) и стоимость этих услуг. 
Описание типа номера сократить до 23 знаков. Столбцы назвать: Гости, Номер, Услуги, 
Стоимость_услуг. Отсортировать по ФИО гостей в алфавитном порядке.  */

SELECT guest_name AS Гости, 
       LEFT(type_room_name, 23) AS Номер, 
       GROUP_CONCAT(DISTINCT service_name ORDER BY service_name SEPARATOR "\n") AS Услуги,
       SUM(service_booking.price) AS Стоимость_услуг
FROM type_room
     JOIN room USING (type_room_id)
     JOIN room_booking USING (room_id)
     JOIN guest USING (guest_id)
     JOIN status USING (status_id)
     JOIN service_booking USING (room_booking_id) 
     JOIN service USING (service_id)
WHERE status_name = 'Занят'
GROUP BY guest_name, type_room_name
ORDER BY 1;


/* Составить рейтинг издательств по популярности их книг. 
Если несколько издательств имеют одинаковую популярность, то выбрать то из них, 
которое имеет большее количество экземпляров в наличии. */

WITH get_publisher (publisher_id, book_count)
AS(
    SELECT publisher_id, COUNT(book_reader.book_id)
      FROM book
           JOIN book_reader USING(book_id)
  GROUP BY publisher_id
    )
SELECT DISTINCT publisher_name AS Издательство, 
       FIRST_VALUE(book_count) OVER win_book AS 'Кол-во'
  FROM publisher
       JOIN get_publisher USING(publisher_id)
       JOIN book USING(publisher_id)
WINDOW win_book 
AS(
    PARTITION BY publisher_name
    ORDER BY book_count DESC, available_numbers DESC
)
ORDER BY 2 DESC;   



/* Определить самую дорогую услугу, которую заказывал каждый гость. Указать, 
какой процент стоимости составила эта услуга относительной полной стоимости 
всех оплаченных гостем услуг. Столбцы назвать: Гость, Услуга, Цена,            
Общ_стоимость, Процент. Информацию отсортировать по убыванию Цены. */

WITH get_service (guest_name, service_name, service_price, sum_price)
AS (
     SELECT guest_name, service_name, service_booking.price, SUM(service_booking.price) OVER win_s
       FROM guest
            JOIN room_booking USING(guest_id)
            JOIN service_booking USING(room_booking_id)
            JOIN service USING(service_id)
     WINDOW win_s 
        AS(
            PARTITION BY guest_name 
            ORDER BY service_booking.price 
         ))
SELECT DISTINCT guest_name AS Гость, 
       FIRST_VALUE(service_name) OVER win_k AS Услуга,
       FIRST_VALUE(service_price) OVER win_k AS Цена,
       FIRST_VALUE(sum_price) OVER win_k AS Общ_стоимость, 
       ROUND(  FIRST_VALUE(service_price) OVER win_k/FIRST_VALUE(sum_price) OVER win_k  * 100) AS Процент
  FROM get_service
WINDOW win_k 
   AS(
       PARTITION BY guest_name
       ORDER BY service_name DESC, service_price DESC
     )
ORDER BY Цена DESC;









