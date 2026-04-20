import { View, Text, StyleSheet } from 'react-native';

export default function GroupDetailScreen() {
  return (
    <View style={styles.container}>
      <Text>Group Detail</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, alignItems: 'center', justifyContent: 'center' },
});
