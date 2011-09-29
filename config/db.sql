drop table Cookie;
drop table Login;



create table Login (
	   login_id			INT PRIMARY KEY NOT NULL,
	   login_password	varchar(64)
	   );
INSERT INTO Login VALUES (1, '$2a$10$6dd891270c64eec268184O7q4sDXZuUbYEWtux5Sm.BkLHvosocxe');
-- clouds

grant all on Login to web;


create table Cookie (
	   cookie_string			char(32),
	   fk_login_id    			int not null references Login(login_id),
	   is_admin					boolean NULL
	   );
create index i_cookie_string on Cookie(cookie_string);	   
create index i_cookie_login on Cookie(fk_login_name);	   

grant all on Cookie to web;


