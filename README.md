# Pickaxe
---
Pickaxe uses SQL statements combined with CSS selectors to pick out text from a web page. If you know SQL and a little about CSS selectors and want to capture data from the web, this is the tool for you.
## Downloads
---
Found [here](https://github.com/bitsummation/pickaxe/releases). It requires .NET framework 4.0. **Pickaxe.zip** contains the GUI editor and only runs on windows. The **Pickaxe-Console.zip** is the command line version that runs on non-windows platforms using mono as well as windows. See Command Line section below.
## Quickstart
---
Download **Pickaxe.zip** from above and unzip the contents and double click on **Pickaxe.Studio.exe** to run the GUI editor. Below is a screen shot of the editor. A full runnable example that scrapes a forum I host is found [here](https://raw.githubusercontent.com/bitsummation/pickaxe/master/Examples/vtss.s). Others can be found [here](https://github.com/bitsummation/pickaxe/tree/master/Examples).

![](https://cloud.githubusercontent.com/assets/13210937/14195656/810cb08e-f781-11e5-9638-960a1659477d.png)

### Download Page
Download page returns a table with columns url, nodes, date, size. The statement below downloads aviation weather information for airports in Texas.
```sql
select *
from download page 'https://www.faa.gov/air_traffic/weather/asos/?state=TX'
```
### Where
Select the nodes we are interested in. To accomplish, set the nodes equal to a css expression. The css selector below gets all tr nodes that are under the table with class asos.
```sql
select *
from download page 'https://www.faa.gov/air_traffic/weather/asos/?state=TX'
where nodes = 'table.asos tbody tr'
```
### Pick
The pick expression picks out nodes under each node specified in the where clause. Pick takes a css selector. In this case, we are getting data in the td elements under each tr element. After the pick css selector, a part of the element can be specified.
* take attribute 'attribute' - takes the attribute value of the node. 
* take text - takes the text of the node (default value and doesn't have to be specified)
* take html - takes the html of the node
```sql
select
	pick 'td:nth-child(1) a' take attribute 'href', --link to details
	pick 'td:nth-child(1) a', --station
	pick 'td:nth-child(2)', --city
	pick 'td:nth-child(4)' --state
from download page 'https://www.faa.gov/air_traffic/weather/asos/?state=TX'	
where nodes = 'table.asos tbody tr'
```
### Nested selects
We create a memory table to store state strings then we insert states into it. The nested select statement allows the download page statement to download multiple pages at once. 
```sql
create buffer states(state string)

insert into states
select 'TX'

insert into states
select 'OR'

select
	pick 'td:nth-child(1) a' take attribute 'href', --link to details
	pick 'td:nth-child(1) a', --station
	pick 'td:nth-child(2)', --city
	pick 'td:nth-child(4)' --state
from download page (select
	'https://www.faa.gov/air_traffic/weather/asos/?state=' + state
	from states)
where nodes = 'table.asos tbody tr'
```
### Download Threads (make it faster)
A download page statement can use with (thread(2)) hint. The download page statement will then use the number of threads specified to download the pages resulting in much better performance. 
```sql
create buffer states(state string)

insert into states
select 'TX'

insert into states
select 'OR'

select
	pick 'td:nth-child(1) a' take attribute 'href', --link to details
	pick 'td:nth-child(1) a', --station
	pick 'td:nth-child(2)', --city
	pick 'td:nth-child(4)' --state
from download page (select
	'https://www.faa.gov/air_traffic/weather/asos/?state=' + state
	from states) with (thread(2))
where nodes = 'table.asos tbody tr'
```
### Proxies
Must be first statement in program. If the expression in the test block returns any rows, the proxy is considered good and all http requests will be routed through it. If more than one passes they are used in Round-robin fashion.
``` sql
proxies ('104.156.252.188:8080', '75.64.204.199:8888', '107.191.49.249:8080')
with test {	
	select
		pick '#tagline' take text
	from download page 'http://vtss.brockreeve.com/'
}
```
### Identity Column
Specify type as identity and it will auto increment.
```sql
create buffer temp(id identity, name string)

insert into temp
select 'test'

insert into temp
select 'test2'

select *
from temp
```
### Storage Buffers
There are three different ways to store results. In memory, files, and sql databases. An example of each is listed below.
#### In Memory Buffer
Store results in memory. The insert overwrite statement overwrites existing data in the buffer--if any--while insert into just appends to existing data.
```sql
create buffer results(type string, folder string, message string, changeDate string)

insert overwrite results
select
    case pick '.icon .octicon-file-text'
        when null then 'Folder'
        else 'File'
    end, --folder/file
    pick '.content a', --name
    pick '.message a', --comment
    pick '.age span' --date
from download page 'https://github.com/bitsummation/pickaxe'
where nodes = 'table.files tr.js-navigation-item'

select *
from results
```
#### File Buffer
Store results into a file.
``` sql
create file results(type string, folder string, message string, changeDate string)
with (
    fieldterminator = '|',
    rowterminator = '\r\n'
)
location 'C:\windows\temp\results.txt'

insert into results
select
    case pick '.icon .octicon-file-text'
        when null then 'Folder'
        else 'File'
    end, --folder/file
    pick '.content a', --name
    pick '.message a', --comment
    pick '.age span' --date
from download page 'https://github.com/bitsummation/pickaxe'
where nodes = 'table.files tr.js-navigation-item'
```
#### SQL Buffer
Store results in Microsoft SQL Server. The mssql buffer definition must match the sql table structure.
``` sql
create mssql results(type string, folder string, message string, changeDate string)
with (
   connectionstring = 'Server=localhost;Database=scrape;Trusted_Connection=True;',
   dbtable = 'Results'
)

insert into results
select
    case pick '.icon .octicon-file-text'
        when null then 'Folder'
        else 'File'
    end, --folder/file
    pick '.content a', --name
    pick '.message a', --comment
    pick '.age span' --date
from download page 'https://github.com/bitsummation/pickaxe'
where nodes = 'table.files tr.js-navigation-item'
```
## Javscript Rendered Pages
---
If a page renders the HTML client side with javascript a simple js hint is all that is needed. Only use if needed as performance is slower.
```sql
select
	pick '.main-link a' take attribute 'href',
	pick '.main-link a',
	pick '.posts span', --replies
	pick '.views span' --views
from download page 'https://try.discourse.org/' with (js)
where nodes = 'tr.topic-list-item'
```
For more control, specify the HTML element to wait for -- will wait until javscript renders the element -- and the time to wait before timing out (in seconds).
```sql
select
	pick '.main-link a' take attribute 'href',
	pick '.main-link a',
	pick '.posts span', --replies
	pick '.views span' --views
from download page 'https://try.discourse.org/' with (js('tr.topic-list-item', 5))
where nodes = 'tr.topic-list-item'
```
## More Examples
---
#### Example 1
Capture the commit information from this page.
```sql
select
	case pick '.icon .octicon-file-text'
		when null then 'Folder'
		else 'File'
	end, --folder/file
	pick '.content a', --name
	pick '.message a', --comment
	pick '.age span' --date
from download page 'https://github.com/bitsummation/pickaxe'
where nodes = 'table.files tr.js-navigation-item'
```
#### Example 2
What's your WAN ip address?
```sql
select
	pick '#section_left div:nth-child(2) a'
from download page 'http://whatismyipaddress.com/'
```
#### Match
The match expression uses regular expressions to match text. In this case, it is just taking the numbers of the ip address.
```sql
select
    pick '#section_left div:nth-child(2) a' match '\d'
from download page 'http://whatismyipaddress.com'
```
#### Match/Replace
A match expression can be followed by a replace. In this case, we replace the dots with dashes.
```sql
select
    pick '#section_left div:nth-child(2) a' match '\.' replace '---'
from download page 'http://whatismyipaddress.com'
```
### Update
Update table.
``` sql
create buffer videos(video string, link string, title string, processed int)

insert into videos
select
	url,
	'https://www.youtube.com' + pick '.content-wrapper a' take attribute 'href',
	pick '.content-wrapper a' take attribute 'title',
	0
from download page 'https://www.youtube.com/watch?v=7NJqUN9TClM'
where nodes = '#watch-related li.video-list-item'

update videos
set processed = 1
where link = 'https://www.youtube.com/watch?v=JYZMT8otKdI'

select *
from videos
```
### Download Images
``` sql
insert file into 'C:\Windows\temp'
select
    filename,
    image
from download image 'http://brockreeve.com/image.axd?picture=2015%2f6%2fheadShot.jpg'
```
#### Variables
Use var to declare variable.
``` sql
var startPage = 1
var endPage = 10
```
#### Expand
Used mostly to generate urls.
``` sql
var startPage = 1
var endPage = 10

select
    'http://example.com/p=' + value + '?t=All'
from expand (startPage to endPage){($*2) + 10}
```
### Join
Inner join tables.
``` sql
create buffer a (id int, name string)
create buffer b (id int, name string)

insert into a
select 1, 'first'

insert into a
select 2, 'first'

insert into b
select 1, 'second'

select a.name, b.name
from a
join b on a.id = b.id
```
### Case
Case statement in select.
``` sql
select
    case when value < 20
    	then 'small' else 'large'
    end
from expand (1 to 10){($*2) + 10}
```

#### Loops
Allows looping through tables.
``` sql
create buffer temp(baseUrl string, startPage int, endPage int)

insert into temp
	select 'http://test.com', 0, 10

insert into temp
	select 'http://temp.com', 2, 10

create buffer urls(url string)

each(var t in temp){
	
	insert into urls
    	select t.baseUrl + value + '?t=All'
    from expand (t.startPage to t.endPage){($*2) + 10}

}

select *
from urls
```
## Command Line
---
The **Pickaxe-Console.zip** contains the command line version. Run pickaxe.exe without any arguments to run in interactive mode. Type in statements and run them by ending statement with a semicolon. Pass the file path to run the program. Command line arguments can be passed to the script.

### Run Program
```
pickaxe c:\test.s arg1 arg2
```
Get command line values in program. The ?? is used to assign a default value if args are not passed on command line.
``` sql
@1 = @1 ?? 'first'
@2 = @2 ?? 'second'
```
### REPL Interactive Mode
To run in interactive mode, run pickaxe.exe without any arguments. Now type in statements. When you want the statement to run, end with a semicolon. The statement will then be executed. See screen shot below:
![](https://cloud.githubusercontent.com/assets/13210937/13126421/f66b240a-d58f-11e5-875c-40344f44b3fe.png)

## Tutorials
---
* [Pickaxe Tutorial #1](http://brockreeve.com/post/2015/07/23/SQL-based-web-scraper-language-Tutorial-1.aspx)
* [Pickaxe Tutorial #2](http://brockreeve.com/post/2015/07/31/SQL-based-web-scraper-language-Tutorial-2.aspx)
* [Pickaxe Tutorial #3](http://brockreeve.com/post/2015/08/06/Pickaxe-August-2015-release-notes.aspx)

[Contact me](http://brockreeve.com/contact.aspx) with feedback/questions.
## Video
---
30 minute in depth video of language features. [Pickaxe Video Tutorial](https://www.youtube.com/watch?v=-F-FftxaXOs)


