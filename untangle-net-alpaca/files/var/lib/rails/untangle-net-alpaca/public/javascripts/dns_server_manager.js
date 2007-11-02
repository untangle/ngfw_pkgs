var DnsServerManager = {
    removeStaticEntry : function( rowId )
    {
        try {
            Element.remove( rowId );
        } catch ( e ) {
            /* ignore exceptions */
        }
    }
};
