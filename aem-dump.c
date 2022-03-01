// SPDX: MIT/ISC/BSD2/Apache2 at your leisure
#include <getopt.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include <libjaylink/libjaylink.h>

int main(int argc, char* argv[]) {

	bool csv_output = false;
	int msecs_delay = 0;

	struct jaylink_context *ctx;
	struct jaylink_device **devs;
	struct jaylink_device_handle *devh;

	ssize_t ret;

	int opt;
	while ((opt = getopt(argc, argv, "cm:")) != -1) {
               switch (opt) {
               case 'c':
                   csv_output = true;
                   break;
               case 'm':
                   msecs_delay = atoi(optarg);
                   break;
               default: /* '?' */
                   fprintf(stderr, "Usage: %s [-m msecs_delay_between_readings] [-c] name\n", argv[0]);
		   fprintf(stderr, "\t-c is for csv output, vs 'human' output. csv is easier to feed to kst2...\n");
                   exit(EXIT_FAILURE);
               }
           }

	ret = jaylink_init(&ctx);
	if (ret != JAYLINK_OK) {
		printf("jaylink_init() failed: %s\n", jaylink_strerror_name(ret));
		return EXIT_FAILURE;
	}

	ret = jaylink_discovery_scan(ctx, 0);
	if (ret != JAYLINK_OK) {
		printf("jaylink_discovery_scan() failed: %s\n",	jaylink_strerror_name(ret));
		jaylink_exit(ctx);
		return EXIT_FAILURE;
	}

	ret = jaylink_get_devices(ctx, &devs, NULL);
	if (ret != JAYLINK_OK) {
		printf("jaylink_get_device_list() failed: %s\n", jaylink_strerror_name(ret));
		jaylink_exit(ctx);
		return EXIT_FAILURE;
	}

	bool device_found = false;
	bool use_serial_number = false;
	uint32_t serial_number;

	for (unsigned i = 0; devs[i]; i++) {
		devh = NULL;
		uint32_t tmp;
		ret = jaylink_device_get_serial_number(devs[i], &tmp);

		if (ret != JAYLINK_OK) {
			printf("jaylink_device_get_serial_number() failed: "
				"%s.\n", jaylink_strerror_name(ret));
			continue;
		}

		if (use_serial_number && serial_number != tmp)
			continue;

		ret = jaylink_open(devs[i], &devh);

		if (ret == JAYLINK_OK) {
			serial_number = tmp;
			device_found = true;
			break;
		}

		printf("jaylink_open() failed: %s.\n",
			jaylink_strerror_name(ret));
	}

	jaylink_free_devices(devs, true);

	if (!device_found) {
		printf("No J-Link device found.\n");
		jaylink_exit(ctx);
		return EXIT_SUCCESS;
	}

	printf("Using J-link with serial: %012u\n", serial_number);


	uint8_t caps[JAYLINK_DEV_EXT_CAPS_SIZE] = {0};

	ret = jaylink_get_caps(devh, caps);
	if (ret != JAYLINK_OK) {
		printf("jaylink_get_caps() failed: %s\n", jaylink_strerror_name(ret));
		jaylink_close(devh);
		jaylink_exit(ctx);
		return EXIT_FAILURE;
	}

	if (jaylink_has_cap(caps, JAYLINK_DEV_CAP_GET_EXT_CAPS)) {
		ret = jaylink_get_extended_caps(devh, caps);

		if (ret != JAYLINK_OK) {
			printf("jaylink_get_extended_caps() failed: %s\n", jaylink_strerror_name(ret));
			jaylink_close(devh);
			jaylink_exit(ctx);
			return EXIT_FAILURE;
		}
	}

	if (!jaylink_has_cap(caps, JAYLINK_DEV_CAP_EMUCOM)) {
		printf("Device does not support EMUCOM.\n");
		jaylink_close(devh);
		jaylink_exit(ctx);
		return EXIT_FAILURE;
	}


	while (1) {
		uint8_t buf[12];
		uint32_t rlen = 12;
		ret = jaylink_emucom_read(devh, 0x10001, buf, &rlen);
		if (ret != JAYLINK_OK) {
			printf("Failed to read emucom? %s\n", jaylink_strerror_name(ret));
			break;
		}
		if (rlen != 12) {
			printf("failed to read expected emucom?! %d != 12\n", rlen);
			break;
		}
		uint32_t ts_ms = (uint32_t)buf[3] << 24 | (uint32_t)buf[2] << 16 | (uint32_t)buf[1] << 8 | (uint32_t)buf[0];
		float current_ma;
		uint32_t current_ma_raw;
		current_ma_raw = (uint32_t)buf[7] << 24 | (uint32_t)buf[6] << 16 | (uint32_t)buf[5] << 8 | (uint32_t)buf[4];
		memcpy(&current_ma, &current_ma_raw, sizeof(current_ma_raw));
		float voltage;
		uint32_t voltage_raw;
		voltage_raw = (uint32_t)buf[11] << 24 | (uint32_t)buf[10] << 16 | (uint32_t)buf[9] << 8 | (uint32_t)buf[8];
		memcpy(&voltage, &voltage_raw, sizeof(voltage_raw));
		if (csv_output) {
			printf("%d;%f;%f\n", ts_ms, current_ma, voltage);
		} else {
			printf(" > ts: %u, current_ma: %f, voltage: %f\n", ts_ms, current_ma, voltage);
		}
		struct timespec littlebit = {.tv_sec = 0, .tv_nsec = msecs_delay * 1000 * 1000 / 2};
		nanosleep(&littlebit, NULL); // like I give a shit about accurate resleeping here ;)
	}


	jaylink_close(devh);
	jaylink_exit(ctx);
	printf("all done!\n");

	return EXIT_SUCCESS;


}
