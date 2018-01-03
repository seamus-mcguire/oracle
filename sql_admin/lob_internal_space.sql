
spool lobs.log append 

set serveroutput on
set feedback off

prompt &_CONNECT_IDENTIFIER

select to_char(sysdate, 'YYYY-MM-DD HH24:MI:SS') time_ from dual;

declare  
    l_segment_name          varchar2(30); 
    l_segment_size_blocks   number; 
    l_segment_size_bytes    number; 
    l_used_blocks           number;  
    l_used_bytes            number;  
    l_expired_blocks        number;  
    l_expired_bytes         number;  
    l_unexpired_blocks      number;  
    l_unexpired_bytes       number;  
    l_pct_reusable          number;  


begin
    select segment_name 
    into l_segment_name 
    from dba_lobs 
    where owner = '&SCHEMA'
	and table_name = 'TABLE'
	and column_name = 'COLUMN';
        dbms_output.put_line('Segment Name=' || l_segment_name);
 
    dbms_space.space_usage( 
        segment_owner           => '&SCHEMA',  
        segment_name            => l_segment_name, 
        segment_type            => 'LOB', 
        partition_name          => NULL, 
        segment_size_blocks     => l_segment_size_blocks, 
        segment_size_bytes      => l_segment_size_bytes, 
        used_blocks             => l_used_blocks, 
        used_bytes              => l_used_bytes, 
        expired_blocks          => l_expired_blocks, 
        expired_bytes           => l_expired_bytes, 
        unexpired_blocks        => l_unexpired_blocks, 
        unexpired_bytes         => l_unexpired_bytes 
    );   

    dbms_output.put_line('segment_size_blocks       => '||  l_segment_size_blocks);
    dbms_output.put_line('segment_size_bytes        => '||  l_segment_size_bytes);
    dbms_output.put_line('used_blocks               => '||  l_used_blocks);
    dbms_output.put_line('used_bytes                => '||  l_used_bytes);
    dbms_output.put_line('expired_blocks            => '||  l_expired_blocks);
    dbms_output.put_line('expired_bytes             => '||  l_expired_bytes);
    dbms_output.put_line('unexpired_blocks          => '||  l_unexpired_blocks);
    dbms_output.put_line('unexpired_bytes           => '||  l_unexpired_bytes);

    l_pct_reusable :=  ROUND(l_expired_blocks/l_segment_size_blocks*100,4);
	dbms_output.put_line('reusable_pct_used         => '||  l_pct_reusable);
end;
/

select to_char(sysdate, 'YYYY-MM-DD HH24:MI:SS') time_ from dual;

set serveroutput off
set feedback on

spool off
