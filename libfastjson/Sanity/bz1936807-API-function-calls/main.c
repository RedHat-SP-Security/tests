#include <assert.h>
#include <stdio.h>
#include <json.h>

int main() {

    fjson_object *json_array = fjson_object_new_array();
    assert(fjson_object_array_length(json_array) == 0);
    const int size = 10;

    for (int i = 0; i < size; i++) {
        fjson_object *json_item = fjson_object_new_int(i);
        fjson_object_array_put_idx(json_array, i, json_item);
    }
    assert(fjson_object_array_length(json_array) == size);

    for (int i = size-1; i >= 0; i--) {
        fjson_object_array_del_idx(json_array, i);
    }
    assert(fjson_object_array_length(json_array) == 0);

    return EXIT_SUCCESS;
}
