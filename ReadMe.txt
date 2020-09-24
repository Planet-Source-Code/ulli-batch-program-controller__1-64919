This is a 'Finite State Machine' Class to control batch type sequential client programs which fetch records from one or more sequential (normally keyed) data streams and optionally merge them into one stream, and/or exchanges data between matching records. This is done by invoking the discrete procedural steps in a logical sequence (eg FetchNextRecord, GroupHeader, ProcessRecord, GroupFooter etc) which the client program is arranged into. Also supported and invoked are control breaks for outputting subtotals, totals or grand totals; the control breaks are further subdivided into group header and group footer. The class supports a great variety of properties which may come in handy during program execution. 

Examples for this kind of programs are manifold: Invoicing, batch account-updating from transactions, grouped statistics, budgets and ballances, or report writers with subtotals and totals to name just a few.

A comprehensive documentation is included. 

Compile WinPS 1st, register it if necessary using RegSvr32, and then add a reference to it to TestNewPS (or to any other project that might be using it).

Download is 85 kB.