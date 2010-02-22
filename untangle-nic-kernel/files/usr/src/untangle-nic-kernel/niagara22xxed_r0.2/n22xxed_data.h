#ifndef _N22XX_H
#define _N22XX_H

#define N22XX_VERSION           0x200
#define N22XX_PARAM_SIZE        0x80

#define N22XX_DRIVER_UNKNOWN    0x0
#define N22XX_IDENTIFY_DRIVER   0x0

#define N22XX_BASE_SIOC    	(SIOCDEVPRIVATE + 10)

enum n22xxed_stat {
    N22XX_STAT_OK,
    N22XX_STAT_BAD_PARAM,
    N22XX_STAT_TEST_FAILED,
    N22XX_STAT_INVALID_STATE,
    N22XX_STAT_NOT_SUPPORTED,
    N22XX_STAT_TEST_FATAL
};

enum spi_stat {
    SPI_STAT_TIMEOUT,
    SPI_STAT_OK,
    SPI_STAT_UNKNOWN,
    SPI_STAT_FAIL
};

struct eeprom_rw_param {
    uint16_t addr;
    uint16_t value;
};

struct n22xxed_data {
    uint32_t 	cmd;
    uint32_t 	pair_num;
    uint32_t 	interface_ver;
    uint32_t 	driver_id;
    uint32_t 	reserved_in[8];
    enum 	n22xxed_stat status;
    uint32_t 	reserved_out[8];
    uint8_t  	max_pair_num;
    uint8_t 	offset;
    uint8_t 	value;
    uint8_t 	fw_rev;
    uint8_t     pos;
    uint16_t    p_addr;
    uint16_t    p_data;
    uint16_t    page[32];
    uint8_t     port;
    uint8_t     num;
    uint32_t    reg_value_a;
    uint32_t    reg_value_b;
    uint16_t    param[N22XX_PARAM_SIZE];
    char        file[30];
    uint8_t     signature[3];
    uint8_t	mac_num;
};

#endif 
